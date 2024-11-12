// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "../../SYBaseWithRewardsUpg.sol";
import "./libraries/AaveAdapterLib.sol";
import "../../../../interfaces/AaveV3/IAaveV3AToken.sol";
import "../../../../interfaces/AaveV3/IAaveV3Pool.sol";
import "../../../../interfaces/AaveV3/IAaveV3IncentiveController.sol";

// @NOTE: In this contract, we denote the "scaled balance" term as "share"

// [NEW] @NOTE: As for the getRewardTokens function, it will check for different incentive controller
// so this implementation should only be used in L2s. L1 would require more gas optimization
contract PendleAaveV3WithRewardsSYUpg is SYBaseWithRewardsUpg {
    using PMath for uint256;

    event NewIncentiveController(address incentiveController);

    error SameIncentiveController();

    // solhint-disable immutable-vars-naming
    address public immutable aToken;
    address public immutable aavePool;
    address public immutable underlying;
    address public immutable incentiveController;
    address public immutable defaultRewardToken;

    uint256[100] private __gap;

    constructor(
        address _aavePool,
        address _aToken,
        address _initialIncentiveController,
        address _defaultRewardToken
    ) SYBaseUpg(_aToken) {
        aToken = _aToken;
        aavePool = _aavePool;
        underlying = IAaveV3AToken(aToken).UNDERLYING_ASSET_ADDRESS();
        incentiveController = _initialIncentiveController;
        defaultRewardToken = _defaultRewardToken;
    }

    function initialize(string memory _name, string memory _symbol) external initializer {
        __SYBaseUpg_init(_name, _symbol);
        _safeApproveInf(underlying, aavePool);
    }

    function _deposit(
        address tokenIn,
        uint256 amountDeposited
    ) internal virtual override returns (uint256 amountSharesOut) {
        if (tokenIn == underlying) {
            IAaveV3Pool(aavePool).supply(underlying, amountDeposited, address(this), 0);
        }
        amountSharesOut = AaveAdapterLib.calcSharesFromAssetUp(amountDeposited, _getNormalizedIncome());
    }

    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal override returns (uint256 amountTokenOut) {
        amountTokenOut = AaveAdapterLib.calcSharesToAssetDown(amountSharesToRedeem, _getNormalizedIncome());
        if (tokenOut == underlying) {
            IAaveV3Pool(aavePool).withdraw(underlying, amountTokenOut, receiver);
        } else {
            _transferOut(aToken, receiver, amountTokenOut);
        }
    }

    function exchangeRate() public view virtual override returns (uint256) {
        return _getNormalizedIncome() / 1e9;
    }

    function _previewDeposit(
        address,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256 /*amountSharesOut*/) {
        return AaveAdapterLib.calcSharesFromAssetUp(amountTokenToDeposit, _getNormalizedIncome());
    }

    function _previewRedeem(
        address,
        uint256 amountSharesToRedeem
    ) internal view virtual override returns (uint256 /*amountTokenOut*/) {
        return AaveAdapterLib.calcSharesToAssetDown(amountSharesToRedeem, _getNormalizedIncome());
    }

    function _getNormalizedIncome() internal view returns (uint256) {
        return IAaveV3Pool(aavePool).getReserveNormalizedIncome(underlying);
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        return ArrayLib.create(underlying, aToken);
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        return ArrayLib.create(underlying, aToken);
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == aToken || token == underlying;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == aToken || token == underlying;
    }

    function assetInfo()
        external
        view
        virtual
        returns (AssetType assetType, address assetAddress, uint8 assetDecimals)
    {
        return (AssetType.TOKEN, underlying, IERC20Metadata(underlying).decimals());
    }

    /*///////////////////////////////////////////////////////////////
                            REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {IStandardizedYield-getRewardTokens}
     */
    function _getRewardTokens() internal view override returns (address[] memory res) {
        return ArrayLib.create(defaultRewardToken);
    }

    function _redeemExternalReward() internal override {
        if (incentiveController != address(0)) {
            IAaveV3IncentiveController(incentiveController).claimAllRewardsToSelf(ArrayLib.create(aToken));
        }
    }
}

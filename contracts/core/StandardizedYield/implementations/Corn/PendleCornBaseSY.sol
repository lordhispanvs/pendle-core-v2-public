// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../SYBase.sol";
import "../../../../interfaces/IPExchangeRateOracle.sol";
import "../../../../interfaces/Corn/ICornSilo.sol";

abstract contract PendleCornBaseSY is SYBase {
    event SetNewExchangeRateOracle(address oracle);

    // solhint-disable immutable-vars-naming
    // solhint-disable const-name-snakecase

    address public constant CORN_SILO = 0x8bc93498b861fd98277c3b51d240e7E56E48F23c;

    address public immutable depositToken;
    address public immutable assetToken;
    address public exchangeRateOracle;

    constructor(
        string memory _name,
        string memory _symbol,
        address _depositToken,
        address _assetToken,
        address _initialExchangeRateOracle
    ) SYBase(_name, _symbol, _depositToken) {
        depositToken = _depositToken;
        assetToken = _assetToken;
        _setExchangeRateOracle(_initialExchangeRateOracle);
        _safeApproveInf(_depositToken, CORN_SILO);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    function _deposit(address /*tokenIn*/, uint256 amountDeposited) internal virtual override returns (uint256) {
        return ICornSilo(CORN_SILO).deposit(depositToken, amountDeposited);
    }

    function _redeem(
        address receiver,
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 amountTokenOut) {
        amountTokenOut = ICornSilo(CORN_SILO).redeemToken(depositToken, amountSharesToRedeem);
        _transferOut(depositToken, receiver, amountTokenOut);
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    function exchangeRate() public view virtual override returns (uint256) {
        return IPExchangeRateOracle(exchangeRateOracle).getExchangeRate();
    }

    function setExchangeRateOracle(address newOracle) external onlyOwner {
        _setExchangeRateOracle(newOracle);
    }

    function _setExchangeRateOracle(address newOracle) internal {
        exchangeRateOracle = newOracle;
        emit SetNewExchangeRateOracle(newOracle);
    }

    /*///////////////////////////////////////////////////////////////
                MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(
        address /*tokenIn*/,
        uint256 amountTokenToDeposit
    ) internal pure override returns (uint256 /*amountSharesOut*/) {
        // For regular token (not Corn BTC), 1 share = 1 token
        return amountTokenToDeposit;
    }

    function _previewRedeem(
        address /*tokenOut*/,
        uint256 amountSharesToRedeem
    ) internal pure override returns (uint256 amountTokenOut) {
        return amountSharesToRedeem;
    }

    function getTokensIn() public view virtual override returns (address[] memory) {
        return ArrayLib.create(depositToken);
    }

    function getTokensOut() public view virtual override returns (address[] memory) {
        return ArrayLib.create(depositToken);
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return token == depositToken;
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return token == depositToken;
    }

    function assetInfo() external view returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
        return (AssetType.TOKEN, assetToken, IERC20Metadata(assetToken).decimals());
    }
}

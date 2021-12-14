// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../interfaces/IPriceOracle.sol";
import "../interfaces/ICErc20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract SimplePriceOracle is IPriceOracle {
    mapping(address => uint) prices;
    event PricePosted(address asset, uint previousPriceMantissa, uint requestedPriceMantissa, uint newPriceMantissa);

    function _getUnderlyingAddress(ICToken cToken) private view returns (address) {
        address asset;
        if (compareStrings(IERC20Metadata(address(cToken)).symbol(), "cETH")) {
            asset = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        } else {
            asset = address(ICErc20(address(cToken)).underlying());
        }
        return asset;
    }

    function getUnderlyingPrice(ICToken cToken) public view returns (uint) {
        return prices[_getUnderlyingAddress(cToken)];
    }

    function setUnderlyingPrice(ICToken cToken, uint underlyingPriceMantissa) public {
        address asset = _getUnderlyingAddress(cToken);
        emit PricePosted(asset, prices[asset], underlyingPriceMantissa, underlyingPriceMantissa);
        prices[asset] = underlyingPriceMantissa;
    }

    function setDirectPrice(address asset, uint price) public {
        emit PricePosted(asset, prices[asset], price, price);
        prices[asset] = price;
    }

    // v1 price oracle interface for use as backing of proxy
    function assetPrices(address asset) external view returns (uint) {
        return prices[asset];
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
}
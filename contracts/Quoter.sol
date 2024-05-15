// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.4;

import {Errors} from "./libraries/Errors.sol";
import "./interfaces/IPriceFeed.sol";
import "./interfaces/IQuoter.sol";

contract Quoter is IQuoter {
    address public manager;
    IPriceFeed public feed;
    address public immutable override WETH;

    event SetManager(address manager);
    event SetPriceFeed(address feed);

    constructor(address _feed, address _WETH) {
        feed = IPriceFeed(_feed);
        WETH = _WETH;
        manager = msg.sender;
    }

    modifier onlyManager() {
        if (msg.sender != manager) revert Errors.Forbidden(msg.sender);
        _;
    }

    function setManager(address _newManager) external onlyManager {
        if (msg.sender == address(0)) revert Errors.ZeroAddress();
        manager = _newManager;

        emit SetManager(_newManager);
    }

    function setFeed(address _newFeed) external onlyManager {
        if (_newFeed == address(0)) revert Errors.ZeroAddress();
        feed = IPriceFeed(_newFeed);

        emit SetPriceFeed(_newFeed);
    }

    function quote(
        address _token,
        uint256 _ethAmount
    ) external view returns (uint256) {
        IPriceFeed _feed = feed;
        uint256 price = _feed.getLowestPrice(WETH, _token);
        uint256 precision = _feed.PRECISION();
        return (_ethAmount * price) / precision;
    }
}

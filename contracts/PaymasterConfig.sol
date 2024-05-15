// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.4;

import {Errors} from "./libraries/Errors.sol";
import "./interfaces/IPaymasterConfig.sol";
import "./interfaces/IQuoter.sol";

contract PaymasterConfig is IPaymasterConfig {
    address public manager;
    IQuoter public quoter;
    mapping(address => bool) public override supportedToken;
    mapping(address => uint256) public override sponsoredRate; // 10000 = 100%

    event SetManager(address manager);
    event SetQuoter(address quoter);
    event SetSupportedToken(address token, bool isAccepted);
    event SetSponsoredRate(address token, uint256 sponsoredRate);

    constructor(address _quoter) {
        quoter = IQuoter(_quoter);
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

    function setQuoter(address _newQuoter) external onlyManager {
        if (_newQuoter == address(0)) revert Errors.ZeroAddress();
        quoter = IQuoter(_newQuoter);

        emit SetQuoter(_newQuoter);
    }

    function setSupportedTokens(
        address[] memory _tokens,
        bool[] memory _isAccepted
    ) external onlyManager {
        if (_tokens.length != _isAccepted.length)
            revert Errors.ArraysLengthMismatch();

        for (uint256 i = 0; i < _tokens.length; i++) {
            supportedToken[_tokens[i]] = _isAccepted[i];
            emit SetSupportedToken(_tokens[i], _isAccepted[i]);
        }
    }

    function setSponsoredRates(
        address[] memory _tokens,
        uint256[] memory _sponsoredRate
    ) external onlyManager {
        if (_tokens.length != _sponsoredRate.length)
            revert Errors.ArraysLengthMismatch();

        for (uint256 i = 0; i < _tokens.length; i++) {
            if (_sponsoredRate[i] > 10000)
                revert Errors.ExceedMaxValue(_sponsoredRate[i], 10000);
            sponsoredRate[_tokens[i]] = _sponsoredRate[i];
            emit SetSponsoredRate(_tokens[i], _sponsoredRate[i]);
        }
    }

    function requiredAmount(
        address _gasToken,
        uint256 _requiredEth
    ) external view override returns (uint256, uint256) {
        uint256 amount = quoter.quote(_gasToken, _requiredEth);
        uint256 _sponsoredRate = sponsoredRate[_gasToken];
        uint256 sponsored = (amount * sponsoredRate[_gasToken]) / 10000;
        amount -= sponsored;
        return (amount, _sponsoredRate);
    }
}

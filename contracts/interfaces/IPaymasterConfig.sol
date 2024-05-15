// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.4;

interface IPaymasterConfig {
    function supportedToken(address) external view returns (bool);

    function sponsoredRate(address) external view returns (uint256);

    function requiredAmount(
        address _gasToken,
        uint256 _requiredEth,
        address _user
    ) external view returns (uint256, uint256);
}

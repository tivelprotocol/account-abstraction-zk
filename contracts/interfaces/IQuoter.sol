// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.4;

interface IQuoter {
    function WETH() external view returns (address);

    function quote(address _token, uint256 _ethAmount) external view returns (uint256);
}

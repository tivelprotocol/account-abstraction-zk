// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.4;

library Errors {
    // Common
    error Forbidden(address sender);
    error ZeroAddress();
    error ArraysLengthMismatch();
    error ExceedMaxValue(uint256 value, uint256 maxValue);

    // Paymaster
    error NotFromBootloader();
    error ShortPaymasterInput();
    error UnsupportedPaymasterFlow();
    error UnsupportedToken(address token);
    error InvalidMarkup();
    error InvalidNonce();
    error InvalidRatio();
    error AllowanceTooLow();
    error FailedTransferToBootloader();
    error FailedTransfer();
}

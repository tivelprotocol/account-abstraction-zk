// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.4;

import {IPaymaster, ExecutionResult, PAYMASTER_VALIDATION_SUCCESS_MAGIC} from "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IPaymaster.sol";
import {IPaymasterFlow} from "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IPaymasterFlow.sol";
import {TransactionHelper, Transaction} from "@matterlabs/zksync-contracts/l2/system-contracts/libraries/TransactionHelper.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Errors} from "./libraries/Errors.sol";

import "./interfaces/IPaymasterConfig.sol";

contract Paymaster is IPaymaster {
    // Using OpenZeppelin's SafeERC20 library to perform token transfers
    using SafeERC20 for IERC20;

    address public manager;
    IPaymasterConfig public config;

    event SetManager(address manager);
    event SetConfig(address config);
    event RefundedToken(
        address indexed account,
        address indexed token,
        uint256 amount
    );

    modifier onlyManager() {
        if (msg.sender != manager) revert Errors.Forbidden(msg.sender);
        _;
    }

    modifier onlyBootloader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert Errors.NotFromBootloader();
        }
        // Continue execution if called from the bootloader.
        _;
    }

    constructor(address _config) {
        config = IPaymasterConfig(_config);
        manager = msg.sender;
    }

    function validateAndPayForPaymasterTransaction(
        bytes32 /* _txHash */,
        bytes32 /* _suggestedSignedHash */,
        Transaction calldata _transaction
    )
        external
        payable
        onlyBootloader
        returns (bytes4 magic, bytes memory context)
    {
        // By default we consider the transaction as accepted.
        magic = PAYMASTER_VALIDATION_SUCCESS_MAGIC;
        if (_transaction.paymasterInput.length < 4)
            revert Errors.ShortPaymasterInput();

        bytes4 paymasterInputSelector = bytes4(
            _transaction.paymasterInput[0:4]
        );
        if (paymasterInputSelector != IPaymasterFlow.approvalBased.selector)
            revert Errors.UnsupportedPaymasterFlow();

        // While the transaction data consists of address, uint256 and bytes data,
        // the data is not needed for this paymaster
        (address token, , ) = abi.decode(
            _transaction.paymasterInput[4:],
            (address, uint256, bytes)
        );

        IPaymasterConfig _config = config;
        if (!_config.supportedToken(token))
            revert Errors.UnsupportedToken(token);

        address userAddress = address(uint160(_transaction.from));
        address thisAddress = address(this);

        // Note, that while the minimal amount of ETH needed is tx.gasPrice * tx.gasLimit,
        // neither paymaster nor account are allowed to access this context variable.
        uint256 requiredETH = _transaction.gasLimit * _transaction.maxFeePerGas;

        (uint256 requiredAmount, uint256 sponsoredRate) = _config
            .requiredAmount(token, requiredETH, userAddress);

        // Flow if the user is required pay with a given token
        if (requiredAmount > 0) {
            // Verifies the user has provided enough allowance
            if (
                IERC20(token).allowance(userAddress, thisAddress) <
                requiredAmount
            ) revert Errors.AllowanceTooLow();

            IERC20(token).safeTransferFrom(
                userAddress,
                thisAddress,
                requiredAmount
            );
        }

        // The bootloader never returns any data, so it can safely be ignored here.
        (bool success, ) = payable(BOOTLOADER_FORMAL_ADDRESS).call{
            value: requiredETH
        }("");
        if (!success) revert Errors.FailedTransferToBootloader();

        // Encode context to process refunds
        context = abi.encode(token, requiredAmount, sponsoredRate);
    }

    function postTransaction(
        bytes calldata _context,
        Transaction calldata _transaction,
        bytes32 /* _txHash */,
        bytes32 /* _suggestedSignedHash */,
        ExecutionResult /* _txResult */,
        uint256 _maxRefundedGas
    ) external payable override onlyBootloader {
        (address token, uint256 requiredAmount, uint256 sponsoredRate) = abi
            .decode(_context, (address, uint256, uint256));

        // Refund the user
        if (requiredAmount > 0) {
            address userAddress = address(uint160(_transaction.from));

            uint256 usedGas = _transaction.gasLimit - _maxRefundedGas;
            uint256 usedGasAfterSponsored = usedGas -
                (usedGas * sponsoredRate) /
                10000;
            uint256 refundAmount = requiredAmount - usedGasAfterSponsored;
            IERC20(token).safeTransfer(userAddress, refundAmount);
            emit RefundedToken(userAddress, token, refundAmount);
        }
    }

    function setManager(address _newManager) external onlyManager {
        if (msg.sender == address(0)) revert Errors.ZeroAddress();
        manager = _newManager;

        emit SetManager(_newManager);
    }

    function setConfig(address _newConfig) external onlyManager {
        if (_newConfig == address(0)) revert Errors.ZeroAddress();
        config = IPaymasterConfig(_newConfig);

        emit SetConfig(_newConfig);
    }

    function withdrawETH(address _to, uint256 _amount) external onlyManager {
        _withdrawETH(_to, _amount);
    }

    function withdrawAllETH(address _to) external onlyManager {
        _withdrawETH(_to, address(this).balance);
    }

    function _withdrawETH(address _to, uint256 _amount) internal {
        if (_to == address(0)) revert Errors.ZeroAddress();
        (bool success, ) = payable(_to).call{value: _amount}("");
        if (!success) revert Errors.FailedTransfer();
    }

    function withdrawERC20(
        address _to,
        address _token,
        uint256 _amount
    ) external onlyManager {
        if (_to == address(0)) revert Errors.ZeroAddress();
        IERC20(_token).safeTransfer(_to, _amount);
    }

    function withdrawERC20Batch(
        address _to,
        address[] calldata _tokens,
        uint256[] calldata _amounts
    ) external onlyManager {
        if (_to == address(0)) revert Errors.ZeroAddress();

        if (_tokens.length != _amounts.length)
            revert Errors.ArraysLengthMismatch();

        for (uint i = 0; i < _tokens.length; i++) {
            IERC20(_tokens[i]).safeTransfer(_to, _amounts[i]);
        }
    }

    receive() external payable {}
}

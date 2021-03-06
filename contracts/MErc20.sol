// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./MToken.sol";
import "./interfaces/IMToken.sol";
import "./interfaces/IController.sol";
import "./interfaces/IInterestRateModel.sol";
import "./interfaces/IMErc20.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Market ERC20 Contract
 * @notice MTokens which wrap an EIP-20 underlying
 * @author Blaize.tech
 */
contract MErc20 is MToken, IMErc20 {
    using SafeERC20 for IERC20;
    /**
     * @notice Underlying asset for this MToken
     */
    address public underlying;

    /**
     * @notice Initialize the new money market
     * @param underlying_ The address of the underlying asset
     * @param controller_ The address of the Comptroller
     * @param interestRateModel_ The address of the interest rate model
     * @param initialExchangeRateMantissa_ The initial exchange rate, scaled by 1e18
     * @param name_ ERC-20 name of this token
     * @param symbol_ ERC-20 symbol of this token
     * @param decimals_ ERC-20 decimal precision of this token
     */
    function initialize(
        address underlying_,
        IController controller_,
        IInterestRateModel interestRateModel_,
        uint256 initialExchangeRateMantissa_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) public {
        // MToken initialize does the bulk of the work
        super.initialize(controller_, interestRateModel_, initialExchangeRateMantissa_, name_, symbol_, decimals_);

        // Set underlying and sanity check it
        underlying = underlying_;
        IERC20(underlying).totalSupply();
    }

    /*** User Interface ***/

    /**
     * @notice Sender supplies assets into the market and receives mTokens in exchange
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param mintAmount The amount of the underlying asset to supply
     */
    function mint(uint256 mintAmount) external returns (uint256) {
        mintInternal(mintAmount);
    }

    /**
     * @notice Sender redeems mTokens in exchange for the underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemTokens The number of mTokens to redeem into underlying
     */
    function redeem(uint256 redeemTokens) external returns (uint256) {
        redeemInternal(redeemTokens);
    }

    /**
     * @notice Sender redeems mTokens in exchange for a specified amount of underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemAmount The amount of underlying to redeem
     */
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256) {
        redeemUnderlyingInternal(redeemAmount);
    }

    /**
     * @notice Sender borrows assets from the protocol to their own address
     * @param borrowAmount The amount of the underlying asset to borrow
     */
    function borrow(uint256 borrowAmount) external returns (uint256) {
        borrowInternal(borrowAmount);
    }

    /**
     * @notice Sender borrows assets from the protcol at a fixed rate for a specified duration
     * @param borrowAmount The amount of the underlying asset to borrow
     * @param maturity Duration, during which the borrow is safe
     */
    function borrowFixedRate(uint256 borrowAmount, uint256 maturity) external {
        borrowFixedRateInternal(borrowAmount, maturity);
    }

    /**
     * @notice Sender repays borrows, taken for fixed rate
     * @param borrowsIndexes Indexes of borrows, which sender wants to repay
     */
    function repayBorrowFixedRate(uint256[] memory borrowsIndexes) external {
        repayBorrowFixedRateInternal(borrowsIndexes);
    }

    /**
     * @notice Sender repays borrows, taken for fixed rate, belonging to borrower
     * @param borrowsIndexes Indexes of borrows, which sender wants to repay
     */
    function repayBorrowFixedRateOnBehalf(address borrower, uint256[] memory borrowsIndexes) external {
        repayBorrowFixedRateOnBehalfInternal(borrower, borrowsIndexes);
    }

    /**
     * @notice Sender repays their own borrow
     * @param repayAmount The amount to repay
     */
    function repayBorrow(uint256 repayAmount) external returns (uint256) {
        repayBorrowInternal(repayAmount);
    }

    /**
     * @notice Sender repays a borrow belonging to borrower
     * @param borrower the account with the debt being payed off
     * @param repayAmount The amount to repay
     */
    function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256) {
        repayBorrowBehalfInternal(borrower, repayAmount);
    }

    /**
     * The sender liquidates the borrowers loans, taken for fixed rate.
     * @param borrower The borrower, which fixed rate borrows to be liquidated
     * @param borrowsIndexes Indexes of borrows, which sender wants to liquidate
     * @param mTokenCollaterals The market in which to seize collateral from the borrower for each borrow
     */
    function liquidateBorrowFixedRate(
        address borrower,
        uint256[] memory borrowsIndexes,
        IMToken[] memory mTokenCollaterals
    ) external {
        liquidateBorrowFixedRateInternal(borrower, borrowsIndexes, mTokenCollaterals);
    }

    /**
     * @notice The sender liquidates the borrowers collateral.
     *  The collateral seized is transferred to the liquidator.
     * @param borrower The borrower of this mToken to be liquidated
     * @param repayAmount The amount of the underlying borrowed asset to repay
     * @param mTokenCollateral The market in which to seize collateral from the borrower
     */
    function liquidateBorrow(
        address borrower,
        uint256 repayAmount,
        IMToken mTokenCollateral
    ) external returns (uint256) {
        liquidateBorrowInternal(borrower, repayAmount, mTokenCollateral);
    }

    /**
     * @notice A public function to sweep accidental ERC-20 transfers to this contract. Tokens are sent to admin (timelock)
     * @param token The address of the ERC-20 token to sweep
     */
    function sweepToken(IERC20 token) external onlyAdmin(msg.sender) {
        require(address(token) != underlying, "CErc20::sweepToken: can not sweep underlying token");
        uint256 balance = token.balanceOf(address(this));
        token.safeTransfer(admin, balance);
    }

    /**
     * @notice The sender adds to reserves.
     * @param addAmount The amount fo underlying token to add as reserves
     */
    function addReserves(uint256 addAmount) external {
        _addReservesInternal(addAmount);
    }

    /*** Safe Token ***/

    /**
     * @notice Gets balance of this contract in terms of the underlying
     * @dev This excludes the value of the current message, if any
     * @return The quantity of underlying tokens owned by this contract
     */
    function getCashPrior() internal view override returns (uint256) {
        IERC20 token = IERC20(underlying);
        return token.balanceOf(address(this));
    }

    /**
     * @dev Similar to EIP20 transfer, except it handles a False result from transferFrom and reverts in that case.
     *      This will revert due to insufficient balance or insufficient allowance.
     *      This function returns the actual amount received,
     *      which may be less than amount if there is a fee attached to the transfer.
     */
    function doTransferIn(address from, uint256 amount) internal override returns (uint256) {
        IERC20 token = IERC20(underlying);
        uint256 balanceBefore = token.balanceOf(address(this));
        token.safeTransferFrom(from, address(this), amount);

        // Calculate the amount that was *actually* transferred
        uint256 balanceAfter = token.balanceOf(address(this));
        return balanceAfter - balanceBefore; // underflow already checked above, just subtract
    }

    /**
     * @dev Similar to EIP20 transfer, except it handles a False success from transfer and returns an explanatory
     *      error code rather than reverting. If caller has not called checked protocol's balance, this may revert due to
     *      insufficient cash held in this contract. If caller has checked protocol's balance prior to this call, and verified
     *      it is >= amount, this should not revert in normal conditions.
     *
     */
    function doTransferOut(address payable to, uint256 amount) internal override {
        IERC20 token = IERC20(underlying);
        token.safeTransfer(to, amount);
    }
}

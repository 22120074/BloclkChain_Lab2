// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Corn.sol";
import "./CornDEX.sol";

error Lending__InvalidAmount();
error Lending__TransferFailed();
error Lending__UnsafePositionRatio();
error Lending__BorrowingFailed();
error Lending__RepayingFailed();
error Lending__PositionSafe();
error Lending__NotLiquidatable();
error Lending__InsufficientLiquidatorCorn();

contract Lending is Ownable {
    uint256 private constant COLLATERAL_RATIO = 120; // 120% collateralization required
    uint256 private constant LIQUIDATOR_REWARD = 10; // 10% reward for liquidators

    Corn private i_corn;
    CornDEX private i_cornDEX;

    mapping(address => uint256) public s_userCollateral; // User's collateral balance
    mapping(address => uint256) public s_userBorrowed; // User's borrowed corn balance

    event CollateralAdded(address indexed user, uint256 indexed amount, uint256 price);
    event CollateralWithdrawn(address indexed user, uint256 indexed amount, uint256 price);
    event AssetBorrowed(address indexed user, uint256 indexed amount, uint256 price);
    event AssetRepaid(address indexed user, uint256 indexed amount, uint256 price);
    event Liquidation(
        address indexed user,
        address indexed liquidator,
        uint256 amountForLiquidator,
        uint256 liquidatedUserDebt,
        uint256 price
    );

    constructor(address _cornDEX, address _corn) Ownable(msg.sender) {
        i_cornDEX = CornDEX(_cornDEX);
        i_corn = Corn(_corn);
        i_corn.approve(address(this), type(uint256).max);
    }

    /**
     * @notice Allows users to add collateral to their account
     */
    function addCollateral() public payable {
        if (msg.value == 0) revert Lending__InvalidAmount();

        s_userCollateral[msg.sender] += msg.value;

        // Lấy giá hiện tại từ DEX để truyền vào Event
        uint256 price = i_cornDEX.currentPrice();

        emit CollateralAdded(msg.sender, msg.value, price);
    }

    /**
     * @notice Allows users to withdraw collateral as long as it doesn't make them liquidatable
     * @param amount The amount of collateral to withdraw
     */
    function withdrawCollateral(uint256 amount) public {
        if (amount == 0) revert Lending__InvalidAmount();
        if (s_userCollateral[msg.sender] < amount) revert Lending__InvalidAmount();

        s_userCollateral[msg.sender] -= amount;

        (bool success, ) = payable(msg.sender).call{ value: amount }("");
        if (!success) revert Lending__TransferFailed();

        // Sau khi rút, kiểm tra xem vị thế còn an toàn không
        _validatePosition(msg.sender);

        uint256 price = i_cornDEX.currentPrice();
        emit CollateralWithdrawn(msg.sender, amount, price);
    }

    /**
     * @notice Calculates the total collateral value for a user based on their collateral balance
     * @param user The address of the user to calculate the collateral value for
     * @return uint256 The collateral value
     */
    function calculateCollateralValue(address user) public view returns (uint256) {
        uint256 ethAmount = s_userCollateral[user];
        if (ethAmount == 0) return 0;

        // Lấy số dư hiện tại của DEX để tính toán giá theo công thức AMM
        uint256 ethReserve = address(i_cornDEX).balance;
        uint256 tokenReserve = i_corn.balanceOf(address(i_cornDEX));

        // xInput: ethAmount, xReserves: ethReserve, yReserves: tokenReserve
        return i_cornDEX.price(ethAmount, ethReserve, tokenReserve);
    }

    /**
     * @notice Calculates the position ratio for a user to ensure they are within safe limits
     * @param user The address of the user to calculate the position ratio for
     * @return uint256 The position ratio
     */
    function _calculatePositionRatio(address user) internal view returns (uint256) {
        uint256 collateralValue = calculateCollateralValue(user);
        uint256 debt = s_userBorrowed[user];

        // Nếu không có nợ, tỷ lệ an toàn là vô cực (dùng số lớn nhất của uint256)
        if (debt == 0) return type(uint256).max;

        // Công thức: (Tài sản * 100) / Nợ
        return (collateralValue * 100) / debt;
    }

    /**
     * @notice Checks if a user's position can be liquidated
     * @param user The address of the user to check
     * @return bool True if the position is liquidatable, false otherwise
     */
    function isLiquidatable(address user) public view returns (bool) {
        // Nếu không có nợ thì không bao giờ bị thanh lý
        if (s_userBorrowed[user] == 0) return false;

        uint256 ratio = _calculatePositionRatio(user);

        // Nếu tỷ lệ < 120 (120%), nghĩa là tài sản không đủ đảm bảo an toàn
        return ratio < COLLATERAL_RATIO;
    }

    /**
     * @notice Internal view method that reverts if a user's position is unsafe
     * @param user The address of the user to validate
     */
    function _validatePosition(address user) internal view {
        if (isLiquidatable(user)) {
            revert Lending__UnsafePositionRatio();
        }
    }

    /**
     * @notice Allows users to borrow corn based on their collateral
     * @param borrowAmount The amount of corn to borrow
     */
    function borrowCorn(uint256 borrowAmount) public {
        // 1. Kiểm tra đầu vào
        if (borrowAmount == 0) {
            revert Lending__InvalidAmount();
        }

        // 2. Tăng số nợ của người dùng
        s_userBorrowed[msg.sender] += borrowAmount;

        // 3. QUAN TRỌNG: Kiểm tra vị thế an toàn (Health Factor)
        // Nếu vay quá 80% giá trị tài sản (tương ứng tỷ lệ < 120%), hàm này sẽ revert
        _validatePosition(msg.sender);

        // 4. Chuyển token CORN cho người dùng
        bool success = i_corn.transfer(msg.sender, borrowAmount);
        if (!success) {
            revert Lending__BorrowingFailed();
        }

        // 5. Bắn sự kiện
        emit AssetBorrowed(msg.sender, borrowAmount, i_cornDEX.currentPrice());
    }

    /**
     * @notice Allows users to repay corn and reduce their debt
     * @param repayAmount The amount of corn to repay
     */
    function repayCorn(uint256 repayAmount) public {
        // 1. Kiểm tra đầu vào
        if (repayAmount == 0) {
            revert Lending__InvalidAmount();
        }

        // 2. Không thể trả quá số nợ đang có
        if (s_userBorrowed[msg.sender] < repayAmount) {
            revert Lending__InvalidAmount(); // Hoặc dùng lỗi custom khác nếu muốn chi tiết hơn
        }

        // 3. Giảm nợ (Checks-Effects-Interactions pattern)
        s_userBorrowed[msg.sender] -= repayAmount;

        // 4. Thu hồi token CORN từ người dùng
        bool success = i_corn.transferFrom(msg.sender, address(this), repayAmount);
        if (!success) {
            revert Lending__RepayingFailed();
        }

        // 5. Bắn sự kiện
        emit AssetRepaid(msg.sender, repayAmount, i_cornDEX.currentPrice());
    }

    /**
     * @notice Allows liquidators to liquidate unsafe positions
     * @param user The address of the user to liquidate
     * @dev The caller must have enough CORN to pay back user's debt
     * @dev The caller must have approved this contract to transfer the debt
     */
    function liquidate(address user) public {}
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MyUSD.sol";
import "./Oracle.sol";
import "./MyUSDStaking.sol";

error Engine__InvalidAmount();
error Engine__UnsafePositionRatio();
error Engine__NotLiquidatable();
error Engine__InvalidBorrowRate();
error Engine__NotRateController();
error Engine__InsufficientCollateral();
error Engine__TransferFailed();

contract MyUSDEngine is Ownable {
    uint256 private constant COLLATERAL_RATIO = 150; // 150% collateralization required
    uint256 private constant LIQUIDATOR_REWARD = 10; // 10% reward for liquidators
    uint256 private constant SECONDS_PER_YEAR = 365 days;
    uint256 private constant PRECISION = 1e18;

    MyUSD private i_myUSD;
    Oracle private i_oracle;
    MyUSDStaking private i_staking;
    address private i_rateController;

    uint256 public borrowRate; // Annual interest rate for borrowers in basis points (1% = 100)

    // Total debt shares in the pool
    uint256 public totalDebtShares;

    // Exchange rate between debt shares and MyUSD (1e18 precision)
    uint256 public debtExchangeRate;
    uint256 public lastUpdateTime;

    mapping(address => uint256) public s_userCollateral;
    mapping(address => uint256) public s_userDebtShares;

    event CollateralAdded(address indexed user, uint256 indexed amount, uint256 price);
    event CollateralWithdrawn(address indexed withdrawer, uint256 indexed amount, uint256 price);
    event BorrowRateUpdated(uint256 newRate);
    event DebtSharesMinted(address indexed user, uint256 amount, uint256 shares);
    event DebtSharesBurned(address indexed user, uint256 amount, uint256 shares);
    event Liquidation(
        address indexed user,
        address indexed liquidator,
        uint256 amountForLiquidator,
        uint256 liquidatedUserDebt,
        uint256 price
    );

    modifier onlyRateController() {
        if (msg.sender != i_rateController) revert Engine__NotRateController();
        _;
    }

    constructor(
        address _oracle,
        address _myUSDAddress,
        address _stakingAddress,
        address _rateController
    ) Ownable(msg.sender) {
        i_oracle = Oracle(_oracle);
        i_myUSD = MyUSD(_myUSDAddress);
        i_staking = MyUSDStaking(_stakingAddress);
        i_rateController = _rateController;
        lastUpdateTime = block.timestamp;
        debtExchangeRate = PRECISION; // 1:1 initially
    }

    // Checkpoint 2: Depositing Collateral & Understanding Value
    function addCollateral() public payable {
        // Kiểm tra xem người dùng có gửi ETH vào không
        if (msg.value == 0) revert Engine__InvalidAmount();

        // Cập nhật số dư tài sản thế chấp của người dùng
        s_userCollateral[msg.sender] += msg.value;
        uint256 currentPrice = i_oracle.getETHUSDPrice();

        // Phát sự kiện
        emit CollateralAdded(msg.sender, msg.value, currentPrice);
    }

    function calculateCollateralValue(address user) public view returns (uint256) {
        uint256 ethAmount = s_userCollateral[user];
        if (ethAmount == 0) return 0;
        return (ethAmount * i_oracle.getETHUSDPrice()) / PRECISION;
    }

    // Checkpoint 3: Interest Calculation System
    function _getCurrentExchangeRate() internal view returns (uint256) {
        // 1. Tính thời gian trôi qua từ lần cập nhật cuối
        uint256 timeElapsed = block.timestamp - lastUpdateTime;

        // 2. Nếu chưa có thời gian trôi qua, trả về tỷ giá cũ
        if (timeElapsed == 0) return debtExchangeRate;

        // 3. Tính lãi suất cộng thêm
        // Công thức: (Tỷ giá * Lãi suất * Thời gian) / (Năm * 10000)
        // Chia 10000 vì borrowRate tính theo basis points (ví dụ 500 = 5%)
        uint256 interest = (debtExchangeRate * borrowRate * timeElapsed) / (SECONDS_PER_YEAR * 10000);
        // 4. Trả về tỷ giá mới
        return debtExchangeRate + interest;
    }

    function _accrueInterest() internal {
        debtExchangeRate = _getCurrentExchangeRate();
        // Cập nhật thời gian chốt sổ là bây giờ
        lastUpdateTime = block.timestamp;
    }

    function _getMyUSDToShares(uint256 amount) internal view returns (uint256) {
        // Lấy tỷ giá hiện tại (bao gồm cả lãi suất chưa chốt)
        uint256 currentRate = _getCurrentExchangeRate();
        // Phép chia luôn làm tròn xuống, nên ta nhân PRECISION trước để giữ độ chính xác
        return (amount * PRECISION) / currentRate;
    }

    // Checkpoint 4: Minting MyUSD & Position Health
    function getCurrentDebtValue(address user) public view returns (uint256) {
        uint256 shares = s_userDebtShares[user];
        if (shares == 0) return 0;
        return (shares * _getCurrentExchangeRate()) / PRECISION;
    }

    function calculatePositionRatio(address user) public view returns (uint256) {
        uint256 collateralValue = calculateCollateralValue(user);
        uint256 debtValue = getCurrentDebtValue(user);

        // Nếu không có nợ, tỷ lệ an toàn là vô cực (trả về số lớn nhất của uint256)
        if (debtValue == 0) return type(uint256).max;

        // Nhân 100 để ra đơn vị phần trăm (ví dụ 150 = 150%)
        return (collateralValue * 100) / debtValue;
    }

    function _validatePosition(address user) internal view {
        uint256 healthFactor = calculatePositionRatio(user);
        // Nếu tỷ lệ < 150 (COLLATERAL_RATIO), báo lỗi Unsafe
        if (healthFactor < COLLATERAL_RATIO) {
            revert Engine__UnsafePositionRatio();
        }
    }

    function mintMyUSD(uint256 mintAmount) public {
        if (mintAmount == 0) revert Engine__InvalidAmount();

        // 1. Luôn cập nhật lãi suất hệ thống trước khi thay đổi nợ
        _accrueInterest();

        // 2. Quy đổi số tiền muốn vay ra số "Cổ phần nợ" (Shares)
        uint256 shares = _getMyUSDToShares(mintAmount);

        // 3. Cộng nợ vào sổ cái
        s_userDebtShares[msg.sender] += shares;
        totalDebtShares += shares;

        // 4. KIỂM TRA AN TOÀN: Sau khi vay xong, tài khoản có bị "báo động đỏ" không?
        // Nếu dưới 150%, lệnh này sẽ revert (hủy) toàn bộ thay đổi ở trên
        _validatePosition(msg.sender);

        // 5. Nếu an toàn, thực sự đúc token MyUSD chuyển vào ví người dùng
        i_myUSD.mintTo(msg.sender, mintAmount);

        emit DebtSharesMinted(msg.sender, mintAmount, shares);
    }

    // Checkpoint 5: Accruing Interest & Managing Borrow Rates
    function setBorrowRate(uint256 newRate) external onlyRateController {
        // THÊM DÒNG NÀY: Kiểm tra với lãi suất tiết kiệm bên contract Staking
        if (newRate < i_staking.savingsRate()) revert Engine__InvalidBorrowRate();

        _accrueInterest();
        borrowRate = newRate;
        emit BorrowRateUpdated(newRate);
    }

    // Checkpoint 6: Repaying Debt & Withdrawing Collateral
    function repayUpTo(uint256 amount) public {
        // 1. Cập nhật lãi suất để tính nợ chính xác nhất
        _accrueInterest();

        // 2. Tính tổng nợ thực tế của người dùng ra MyUSD
        uint256 currentDebt = getCurrentDebtValue(msg.sender);

        // 3. Nếu trả thừa thì chỉ lấy đủ số nợ thôi
        uint256 amountToRepay = amount > currentDebt ? currentDebt : amount;

        // 4. Quy đổi số tiền trả ra số Shares cần trừ
        uint256 sharesToBurn = _getMyUSDToShares(amountToRepay);

        // 5. Trừ Shares trong sổ cái
        s_userDebtShares[msg.sender] -= sharesToBurn;
        totalDebtShares -= sharesToBurn;

        // 6. Thu hồi MyUSD từ ví người dùng và Đốt bỏ
        bool success = i_myUSD.transferFrom(msg.sender, address(this), amountToRepay);
        if (!success) revert Engine__TransferFailed();
        i_myUSD.burn(amountToRepay);

        emit DebtSharesBurned(msg.sender, amountToRepay, sharesToBurn);
    }

    function withdrawCollateral(uint256 amount) external {
        if (amount == 0) revert Engine__InvalidAmount();
        if (s_userCollateral[msg.sender] < amount) revert Engine__InsufficientCollateral();

        // 1. Trừ số dư trước (Checks-Effects-Interactions pattern)
        s_userCollateral[msg.sender] -= amount;

        // 2. QUAN TRỌNG: Kiểm tra xem rút xong tỷ lệ nợ có an toàn không?
        _validatePosition(msg.sender);

        // 3. Chuyển ETH trả lại ví người dùng
        (bool success, ) = payable(msg.sender).call{ value: amount }("");
        if (!success) revert Engine__TransferFailed();

        emit CollateralWithdrawn(msg.sender, amount, i_oracle.getETHUSDPrice());
    }

    // Checkpoint 7: Liquidation - Enforcing System Stability
    function isLiquidatable(address user) public view returns (bool) {
        // Nếu tỷ lệ an toàn < 150% thì trả về true (được phép thanh lý)
        return calculatePositionRatio(user) < COLLATERAL_RATIO;
    }

    function liquidate(address user) external {
        // 1. Phải dồn lãi TRƯỚC để biết nợ thực sự hiện tại là bao nhiêu
        _accrueInterest();

        // 2. Kiểm tra lại điều kiện thanh lý ngay tại thời điểm này
        if (!isLiquidatable(user)) revert Engine__NotLiquidatable();

        uint256 debtAmount = getCurrentDebtValue(user);
        uint256 debtShares = s_userDebtShares[user];
        uint256 ethPrice = i_oracle.getETHUSDPrice();

        // 3. Tính toán lượng tài sản thu hồi: (Nợ * 110) / Giá ETH
        // Dùng PRECISION để đảm bảo không mất chữ số thập phân
        uint256 collateralToSeize = (debtAmount * (100 + LIQUIDATOR_REWARD) * PRECISION) / (ethPrice * 100);

        // 4. Kiểm tra nếu user không đủ collateral để trả (trường hợp nợ xấu nặng)
        if (collateralToSeize > s_userCollateral[user]) {
            collateralToSeize = s_userCollateral[user];
        }

        // 5. Cập nhật trạng thái TRƯỚC khi chuyển tiền (Chống Reentrancy)
        s_userDebtShares[user] = 0;
        totalDebtShares -= debtShares;
        s_userCollateral[user] -= collateralToSeize;

        // 6. Thực hiện chuyển tiền
        bool success = i_myUSD.transferFrom(msg.sender, address(this), debtAmount);
        if (!success) revert Engine__TransferFailed();
        i_myUSD.burn(debtAmount);

        (bool successEth, ) = payable(msg.sender).call{ value: collateralToSeize }("");
        if (!successEth) revert Engine__TransferFailed();

        emit Liquidation(user, msg.sender, collateralToSeize, debtAmount, ethPrice);
    }
}

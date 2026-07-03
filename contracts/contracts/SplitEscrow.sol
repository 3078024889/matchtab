// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @title SplitEscrow
/// @notice Holds each participant's share of a group bill in escrow (USDT) until
///         everyone has paid, then releases the full amount to the organizer in
///         one transaction. If the deadline passes before the tab is fully paid,
///         each participant can reclaim exactly what they contributed. No party —
///         including the contract deployer — can move funds out any other way.
contract SplitEscrow {
    struct Tab {
        address organizer;
        address token;
        uint256 totalAmount;
        uint256 collected;
        uint256 deadline;
        bool released;
    }

    uint256 public nextTabId;
    mapping(uint256 => Tab) public tabs;
    mapping(uint256 => mapping(address => uint256)) public contributions;

    event TabCreated(uint256 indexed tabId, address indexed organizer, address token, uint256 totalAmount, uint256 deadline);
    event SharePaid(uint256 indexed tabId, address indexed payer, uint256 amount, uint256 collected);
    event TabReleased(uint256 indexed tabId, address indexed organizer, uint256 totalAmount);
    event Refunded(uint256 indexed tabId, address indexed payer, uint256 amount);

    function createTab(address token, uint256 totalAmount, uint256 deadlineSecondsFromNow) external returns (uint256 tabId) {
        require(token != address(0), "invalid token");
        require(totalAmount > 0, "amount must be > 0");

        tabId = nextTabId++;
        tabs[tabId] = Tab({
            organizer: msg.sender,
            token: token,
            totalAmount: totalAmount,
            collected: 0,
            deadline: block.timestamp + deadlineSecondsFromNow,
            released: false
        });

        emit TabCreated(tabId, msg.sender, token, totalAmount, tabs[tabId].deadline);
    }

    function payShare(uint256 tabId, uint256 amount) external {
        Tab storage tab = tabs[tabId];
        require(tab.organizer != address(0), "tab does not exist");
        require(!tab.released, "tab already released");
        require(block.timestamp <= tab.deadline, "tab expired, refund instead");
        require(amount > 0, "amount must be > 0");
        require(tab.collected + amount <= tab.totalAmount, "would exceed tab total");

        bool ok = IERC20(tab.token).transferFrom(msg.sender, address(this), amount);
        require(ok, "transferFrom failed");

        contributions[tabId][msg.sender] += amount;
        tab.collected += amount;

        emit SharePaid(tabId, msg.sender, amount, tab.collected);

        if (tab.collected == tab.totalAmount) {
            tab.released = true;
            bool sent = IERC20(tab.token).transfer(tab.organizer, tab.collected);
            require(sent, "release transfer failed");
            emit TabReleased(tabId, tab.organizer, tab.collected);
        }
    }

    function refund(uint256 tabId) external {
        Tab storage tab = tabs[tabId];
        require(tab.organizer != address(0), "tab does not exist");
        require(!tab.released, "tab already released, nothing to refund");
        require(block.timestamp > tab.deadline, "tab has not expired yet");

        uint256 owed = contributions[tabId][msg.sender];
        require(owed > 0, "nothing to refund");

        contributions[tabId][msg.sender] = 0;
        tab.collected -= owed;

        bool ok = IERC20(tab.token).transfer(msg.sender, owed);
        require(ok, "refund transfer failed");

        emit Refunded(tabId, msg.sender, owed);
    }

    function remaining(uint256 tabId) external view returns (uint256) {
        Tab storage tab = tabs[tabId];
        if (tab.collected >= tab.totalAmount) return 0;
        return tab.totalAmount - tab.collected;
    }
}
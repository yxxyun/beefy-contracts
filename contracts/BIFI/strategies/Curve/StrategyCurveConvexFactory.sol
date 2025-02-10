// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../interfaces/convex/IConvex.sol";
import "../../interfaces/curve/ICrvMinter.sol";
import "../../interfaces/curve/IRewardsGauge.sol";
import "../Common/BaseAllToNativeFactoryStrat.sol";

// Curve L1 strategy switchable between Curve and Convex
contract StrategyCurveConvexFactory is BaseAllToNativeFactoryStrat {
    using SafeERC20 for IERC20;

    // this `pid` means we using Curve gauge and not Convex rewardPool
    uint constant public NO_PID = 42069;

    IConvexBooster public constant booster = IConvexBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    ICrvMinter public constant minter = ICrvMinter(0xd061D61a4d941c39E5453435B6345Dc261C2fcE0);

    address public gauge; // curve gauge
    address public rewardPool; // convex base reward pool
    uint public pid; // convex booster poolId

    bool public isCrvMintable; // if CRV can be minted via Minter (gauge is added to Controller)
    bool public isCurveRewardsClaimable; // if extra rewards in curve gauge should be claimed
    bool public skipEarmarkRewards;

    function initialize(
        address _gauge,
        uint _pid,
        address[] calldata _rewards,
        Addresses calldata _addresses
    ) public initializer {
        gauge = _gauge;
        pid = _pid;

        if (_pid != NO_PID) {
            (,,, rewardPool,,) = booster.poolInfo(_pid);
        }
        isCurveRewardsClaimable = true;

        __BaseStrategy_init(_addresses, _rewards);
    }

    function stratName() public pure override returns (string memory) {
        return "CurveConvex";
    }

    function balanceOfPool() public view override returns (uint) {
        if (rewardPool != address(0)) {
            return IConvexRewardPool(rewardPool).balanceOf(address(this));
        } else {
            return IRewardsGauge(gauge).balanceOf(address(this));
        }
    }

    function _deposit(uint amount) internal override {
        if (rewardPool != address(0)) {
            IERC20(want).forceApprove(address(booster), amount);
            booster.deposit(pid, amount, true);
        } else {
            IERC20(want).forceApprove(gauge, amount);
            IRewardsGauge(gauge).deposit(amount);
        }
    }

    function _withdraw(uint amount) internal override {
        if (amount > 0) {
            if (rewardPool != address(0)) {
                IConvexRewardPool(rewardPool).withdrawAndUnwrap(amount, false);
            } else {
                IRewardsGauge(gauge).withdraw(amount);
            }
        }
    }

    function _emergencyWithdraw() internal override {
        _withdraw(balanceOfPool());
    }

    function _claim() internal override {
        if (rewardPool != address(0)) {
            if (!skipEarmarkRewards && IConvexRewardPool(rewardPool).periodFinish() < block.timestamp) {
                booster.earmarkRewards(pid);
            }
            IConvexRewardPool(rewardPool).getReward();
        } else {
            if (isCrvMintable) minter.mint(gauge);
            if (isCurveRewardsClaimable) IRewardsGauge(gauge).claim_rewards(address(this));
        }
    }

    function _verifyRewardToken(address token) internal view override {
        require(token != gauge, "!gauge");
        require(token != rewardPool, "!rewardPool");
    }

    function setConvexPid(uint _pid) external onlyManager {
        setConvexPid(_pid, false);
    }

    function setConvexPid(uint _pid, bool claim) public onlyManager {
        if (pid == _pid) return;

        _withdraw(balanceOfPool());
        if (claim) _claim();

        if (_pid != NO_PID) {
            (address _lp,, address _gauge, address _rewardPool,,) = booster.poolInfo(_pid);
            require(want == _lp, "!lp");
            require(gauge == _gauge, "!gauge");
            rewardPool = _rewardPool;
        } else {
            rewardPool = address(0);
        }
        pid = _pid;
        deposit();
    }

    function setCrvMintable(bool _isCrvMintable) external onlyManager {
        isCrvMintable = _isCrvMintable;
    }

    function setCurveRewardsClaimable(bool _isCurveRewardsClaimable) external onlyManager {
        isCurveRewardsClaimable = _isCurveRewardsClaimable;
    }

    function setSkipEarmarkRewards(bool _skipEarmarkRewards) external onlyManager {
        skipEarmarkRewards = _skipEarmarkRewards;
    }

}

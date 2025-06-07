//SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "../src/MultiTokenStaking.sol";
import "../lib/forge-std/src/Test.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20("name", "symbol") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MultiERC20StakingTest is Test {
    MultiERC20Staking public stakingContract;
    TestToken public stakeToken1;
    TestToken public stakeToken2;
    TestToken public rewardToken1;
    TestToken public rewardToken2;

    address public user = vm.addr(1);
    //address public user;

    uint256 constant AMOUNT = 100 ether;
    uint256 constant REWARD_RATE = 0.000000001 ether;

    // vika se predi vsqka funkciq za da moje da se setupne
    function setUp() public {
        stakingContract = new MultiERC20Staking();

        // suzdava se stake tokena i reward tokena
        stakeToken1 = new TestToken("stakeToken1", "TT1");
        stakeToken2 = new TestToken("stakeToken2", "TT2");
        rewardToken1 = new TestToken("rewardToken1", "RT1");
        rewardToken2 = new TestToken("rewardToken2", "RT2");

        // zadavame pozvoleniqt token s zaradi admin funkciqta setAllowedToken v main contracta, zaedno s reward tokena i reward rate an tokena
        stakingContract.setAllowedToken(address(stakeToken1), true);
        stakingContract.setAllowedToken(address(stakeToken2), true);
        stakingContract.setRewardToken(address(stakeToken1), address(rewardToken1));
        stakingContract.setRewardToken(address(stakeToken2), address(rewardToken2));
        stakingContract.setRewardRate(address(stakeToken1), REWARD_RATE);
        stakingContract.setRewardRate(address(stakeToken2), REWARD_RATE);

        //mintvane na token za user i reward pool
        stakeToken1.mint(user, AMOUNT);
        stakeToken2.mint(user, AMOUNT);

        rewardToken1.mint(address(stakingContract), 100 ether);
        rewardToken2.mint(address(stakingContract), 1 ether);

        // mock
        vm.startPrank(user);
        stakeToken1.approve(address(stakingContract), type(uint256).max);
        stakeToken2.approve(address(stakingContract), type(uint256).max);
        vm.stopPrank();
    }

    function testStake() public {
        vm.startPrank(user);

        stakingContract.stake(address(stakeToken1), 100 ether);
        stakingContract.stake(address(stakeToken2), 50 ether);

        vm.stopPrank();
    }
     // expectRevert trqbva da ima predi vsqka funkciaq koqto se vika i da revertne 
    function testStakeWithoutAmount() public {
        vm.startPrank(user);

        stakeToken1.approve(address(stakeToken1), 0);

        vm.expectRevert(MultiERC20Staking.ZeroAmount.selector);

        stakingContract.stake(address(stakeToken1), 0);

        stakeToken2.approve(address(stakeToken2), 0);
        vm.expectRevert(MultiERC20Staking.ZeroAmount.selector);

        stakingContract.stake(address(stakeToken2), 0);

        vm.stopPrank();
    }

    // function testWithdraw() public {
    //     vm.startPrank(user);
    //     stakingContract.withdraw(address(stakeToken1));
    //     vm.stopPrank();
    // }

    function testWithdraw() public {
        vm.startPrank(user);

        stakingContract.stake(address(stakeToken1), 1 ether);
        stakingContract.stake(address(stakeToken2), 9 ether);

        vm.warp(block.timestamp + 6 days);

        stakingContract.withdraw(address(stakeToken1));
        stakingContract.withdraw(address(stakeToken2));

        vm.stopPrank();
    }

    function testWithdrawWithoutStake() public {
        vm.startPrank(user);

        vm.expectRevert(MultiERC20Staking.ZeroAmount.selector);
        stakingContract.withdraw(address(stakeToken1));
        
        vm.expectRevert(MultiERC20Staking.ZeroAmount.selector);
        stakingContract.withdraw(address(stakeToken2));
        

        vm.stopPrank();
    }
}



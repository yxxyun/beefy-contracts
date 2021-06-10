// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

interface IUpgradeableStrategy {
    function want() external view returns (address);
    function deposit() external;
    function withdraw(uint256) external;
    function balanceOf() external view returns (uint256);
    function harvest() external;
    function retireStrat() external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC4671.sol";

interface IERC4671Enumerable is IERC4671 {
    /// @return emittedCount Number of tokens emitted
    function emittedCount() external view returns (uint256);

    /// @return holdersCount Number of token holders
    function holdersCount() external view returns (uint256);
}

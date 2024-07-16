// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/GaussianCDF.sol";

contract TestErfc is Test {
    function testFuzz_valueTooLow(int256 x) public pure {
        vm.assume(x <= -GaussianCDF.ERFC_BOUND);
        int256 y = GaussianCDF.erfc(x);
        assertEq(y, int256(2 ether));
    }

    function testFuzz_valueTooHigh(int256 x) public pure {
        vm.assume(x >= GaussianCDF.ERFC_BOUND);
        int256 y = GaussianCDF.erfc(x);
        assertEq(y, 0);
    }

    function testFuzz_valueNegativeBound(int256 x) public pure {
        vm.assume(x > -GaussianCDF.ERFC_BOUND);
        vm.assume(x <= -1 wei);
        int256 y = GaussianCDF.erfc(x);
        assertGe(y, 1 ether - 0.0000001 ether); //1e-7 precision error for extremely small 18 decimal fixed point values (consistent with errcw/gaussian)
        assertLe(y, 2 ether); 
    }

    function testFuzz_valuePositiveBounds(int256 x) public pure {
        vm.assume(x >= 1 wei);
        vm.assume(x < GaussianCDF.ERFC_BOUND);
        int256 y = GaussianCDF.erfc(x);
        assertGe(y, 0 ether);
        assertLe(y, 1 ether + 0.0000001 ether); //1e-7 precision error for extremely small 18 decimal fixed point values (consistent with errcw/gaussian)
    }
}
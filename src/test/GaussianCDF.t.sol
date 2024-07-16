// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/GaussianCDF.sol";

contract TestGaussian is Test {
    uint256 internal constant EPSILON = 0.00000001 ether; //Error less than 1e-8
        
    function testCDFComputation() public pure {
        assertApproxEqRel(
            GaussianCDF.cdf(94.79555522025787 ether, 94.45009839254658 ether, 0.3360716302603173 ether),
            int256(0.8480077154950457 ether),
            EPSILON
        );
    }

    function testCDFBoundsRevert() public {
        // X should be in [-1e23, 1e23]
        vm.expectRevert(GaussianCDF.XOutOfBounds.selector);
        GaussianCDF.cdf(100001 ether, 0 ether, 1 ether);

        vm.expectRevert(GaussianCDF.XOutOfBounds.selector);
        GaussianCDF.cdf(-100001 ether, 0 ether, 1 ether);

        // Mean should be in [-1e20, 1e20]
        vm.expectRevert(GaussianCDF.MuOutOfBounds.selector);
        GaussianCDF.cdf(0 ether, 101 ether, 1 ether);

        vm.expectRevert(GaussianCDF.MuOutOfBounds.selector);
        GaussianCDF.cdf(0 ether, -101 ether, 1 ether);

        // Sd should be in (0, 1e19]
        vm.expectRevert(GaussianCDF.SigmaOutOfBounds.selector);
        GaussianCDF.cdf(0 ether, 1 ether, 11 ether);

        vm.expectRevert(GaussianCDF.SigmaOutOfBounds.selector);
        GaussianCDF.cdf(0 ether, 1 ether, 0 ether);
    }
}

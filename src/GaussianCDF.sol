// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "solmate/utils/FixedPointMathLib.sol";
import "src/lib/ComputeUtils.sol";

/// @author GA006
/// @notice Library for computing the Cumulative Distrubtion Function (CDF) of a Gaussian Distribution.
/// @custom:epsilon Maximum CDF error vs https://github.com/errcw/gaussian is 1e-13.
/// @custom:source Implementation of https://github.com/errcw/gaussian (CDF part) in Solidity.
/// @custom:source https://github.com/primitivefinance/solstat served as a stepping-stone.
library GaussianCDF {
    /// @notice X is outside of the range [1e-23,1e23].
    error XOutOfBounds();
    /// @notice Mean is outside of the range [1e-20,1e20].
    error MuOutOfBounds();
    /// @notice Standard Deviation is outside of the range (0,1e19].
    error SigmaOutOfBounds();

    /// @notice Upper bound for x, μ, and σ.
    /// @dev The lower bound for x and μ is the corresponding negative upper bound, while σ's lower bound is 0. 
    int256 internal constant X_BOUND = 1e23;
    int256 internal constant MU_BOUND = 1e20;
    int256 internal constant SIGMA_BOUND = 1e19;

    /// @notice Constants used for arithmetic operations.
    int256 internal constant SIGN = -1;
    int256 internal constant WAD = 1e18;
    int256 internal constant TWO_WAD = 2e18;
    int256 internal constant SQRT2 = 1_414213562373095048;

    /// @notice Upper bound for accepted ERFC inputs.
    /// @dev For a Gaussian distribution with parameters μ and σ of type JS number, if x is ~8.3 σ
    /// away from the μ, then the score is either 0 or 1. Given the ERFC input is [-(x - µ) / (σ√2)],
    /// ~8.3 σ from the μ translates into input of ~5.9 Wad. Over this symmetric bound, we can safely 
    /// conclude the value of the ERFC without performing unnecessary calculations, given we want to 
    /// maintain the same behaviour as https://github.com/errcw/gaussian. It should be noted that 
    /// strictly speaking 18 decimal fixed point int256 in Solidity is more precise than JS number
    /// and precision is preserved up to ~6.24 Wad, but anything over ~5.9 Was is unneeded computation.
    int256 internal constant ERFC_BOUND = 59e17;
    /// @notice ERFC approximation constants.
    int256 internal constant ERFC_A = 1_265512230000000000;
    int256 internal constant ERFC_B = 1_000023680000000000;
    int256 internal constant ERFC_C = 374091960000000000; 
    int256 internal constant ERFC_D = 96784180000000000;
    int256 internal constant ERFC_E = -186288060000000000;
    int256 internal constant ERFC_F = 278868070000000000;
    int256 internal constant ERFC_G = -1_135203980000000000;
    int256 internal constant ERFC_H = 1_488515870000000000;
    int256 internal constant ERFC_I = -822152230000000000;
    int256 internal constant ERFC_J = 170872770000000000;

    /// @notice Approximation of the Complementary Error Function (ERFC).
    /// @dev Step is used to avoid `stack too deep`.
    /// There are three input scenarios, keep in mind that the input is negated:
    /// 1. If input is higher than the upper bound, returns 0 as input is more than ~8.3 σ away from the μ on the left.
    /// 2. If input is lower than the lower bound, returns 2 as input is more than ~8.3 σ away from the μ on the right.
    /// 3. If input is within the bounds, returns a value in the interval [0,2].
    /// @param input The value from [-(x - µ) / (σ√2)].
    /// @return output The approximated value of ERFC. 
    /// @custom:source https://www.grad.hr/nastava/gs/prg/NumericalRecipesinC.pdf C implementation of ERFC on page 221.
    /// @custom:source https://mathworld.wolfram.com/Erfc.html definition of ERFC.
    function erfc(int256 input) internal pure returns (int256 output) {
        if (input >= ERFC_BOUND) return 0;
        if (input <= -ERFC_BOUND) return TWO_WAD;

        uint256 z = ComputeUtils.abs(input);
        int256 t;
        int256 k;
        int256 step;
        assembly {
            let nominator := mul(WAD, WAD)
            let denominator := add(WAD, sdiv(mul(z, WAD), TWO_WAD))
            t := sdiv(nominator, denominator)

            function muli(x, y) -> res {
                res := mul(x, y)

                if iszero(or(iszero(x), eq(sdiv(res, x), y))) {
                    revert(0, 0)
                }

                res := sdiv(res, WAD)
            }

            {
                step := add(
                    ERFC_F,
                    muli(
                        t,
                        add(
                            ERFC_G,
                            muli(
                                t,
                                add(
                                    ERFC_H,
                                    muli(t, add(ERFC_I, muli(t, ERFC_J)))
                                )
                            )
                        )
                    )
                )
            }
            {
                step := muli(
                    t,
                    add(
                        ERFC_B,
                        muli(
                            t,
                            add(
                                ERFC_C,
                                muli(
                                    t,
                                    add(
                                        ERFC_D,
                                        muli(t, add(ERFC_E, muli(t, step)))
                                    )
                                )
                            )
                        )
                    )
                )
            }

            k := add(sub(mul(SIGN, muli(z, z)), ERFC_A), step)
        }

        int256 expWad = FixedPointMathLib.expWad(k);
        int256 r;
        assembly {
            r := sdiv(mul(t, expWad), WAD)
            switch iszero(slt(input, 0))
            case 0 {
                output := sub(TWO_WAD, r)
            }
            case 1 {
                output := r
            }
        }
    }

    /// @notice Approximation of the Cumulative Distribution Function (CDF) of a Gaussian Distribution.
    /// @dev CDF is equal to f(x,μ,σ) = 0.5[erfc(-(x - µ) / (σ√2))].
    /// The CDF is approximated through a Complementary Error Function (ERFC) as the
    /// integral that defines the CDF cannot be expressed in a closed-form solution.
    /// @param x The input value which is in the range [1e-23,1e23].
    /// @param mu The mean of the distribution which is in the range [1e-20,1e20].
    /// @param sigma The standard deviation of the distribution which is in the range (0,1e19].
    /// @return z The CDF value, in the range [0,1], for input (x), mean (μ), and standard deviation (σ).
    /// @custom:source https://en.wikipedia.org/wiki/Error_function how ERFC relates to Gaussian approximation.
    function cdf(int256 x, int256 mu, int256 sigma) internal pure returns (int256 z) {
        if (x < -X_BOUND || x > X_BOUND) revert XOutOfBounds();
        if (mu < -MU_BOUND || mu > MU_BOUND) revert MuOutOfBounds();
        if (sigma <= 0 || sigma > SIGMA_BOUND) revert SigmaOutOfBounds();

        int256 negated;
        assembly {
            let nominator := mul(mul(sub(x, mu), WAD), WAD)
            let denominator := mul(SQRT2, sigma)
            let input := sdiv(nominator, denominator)
            negated := add(not(input), 1)
        }

        int256 _erfc = erfc(negated);
        assembly {
            z := sdiv(mul(WAD, _erfc), TWO_WAD)
        }
    }
}

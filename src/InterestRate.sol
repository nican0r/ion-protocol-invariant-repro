// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IYieldOracle } from "src/interfaces/IYieldOracle.sol";
import { RoundedMath } from "src/libraries/math/RoundedMath.sol";

import { safeconsole as console } from "forge-std/safeconsole.sol";

struct IlkData {
    //                                                 _
    uint96 adjustedProfitMargin; // 27 decimals         |
    uint96 minimumKinkRate; // 27 decimals              |
    uint24 adjustedAboveKinkSlope; // 4 decimals        |   256 bits
    uint24 minimumAboveKinkSlope; // 4 decimals         |
    uint16 adjustedReserveFactor; // 4 decimals        _|
    //                                                  |
    uint16 minimumReserveFactor; // 4 decimals          |
    uint96 adjustedBaseRate; // 27 decimals             |   240 bits
    uint96 minimumBaseRate; // 27 decimals              |
    uint16 optimalUtilizationRate; // 4 decimals        |
    uint16 distributionFactor; // 4 decimals           _|
}

// forgefmt: disable-start

// Word 1
//
//                                                256  240   216   192                     96                      0
//                                                 |    |     |     |     min_kink_rate     |   adj_profit_margin  |
//                                                   ^     ^     ^
//                                   adj_reserve_factor    ^   adj_above_kink_slope
//                                                       min_above_kink_slope

uint256 constant ADJUSTED_PROFIT_MARGIN_MASK =    0x0000000000000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF; 
uint256 constant MINIMUM_KINK_RATE_MASK =         0x0000000000000000FFFFFFFFFFFFFFFFFFFFFFFF000000000000000000000000;
uint256 constant ADJUSTED_ABOVE_KINK_SLOPE_MASK = 0x0000000000FFFFFF000000000000000000000000000000000000000000000000;
uint256 constant MINIMUM_ABOVE_KINK_SLOPE_MASK =  0x0000FFFFFF000000000000000000000000000000000000000000000000000000;
uint256 constant ADJUSTED_RESERVE_FACTOR_MASK =   0xFFFF000000000000000000000000000000000000000000000000000000000000; 

// Word 2
//
//                                                256  240 224 208                     112                     16   0
//                                                 | __ |   |   |     min_base_rate     |     adj_base_rate     |   |
//                                                        ^   ^                                                   ^
//                                                        ^  opt_util                                            min_reserve_factor
//                                       distribution_factor

uint256 constant MINIMUM_RESERVE_FACTOR_MASK =    0x000000000000000000000000000000000000000000000000000000000000FFFF;
uint256 constant ADJUSTED_BASE_RATE_MASK =        0x000000000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF0000;
uint256 constant MINIMUM_BASE_RATE_MASK =         0x000000000000FFFFFFFFFFFFFFFFFFFFFFFF0000000000000000000000000000;
uint256 constant OPTIMAL_UTILIZATION_MASK =       0x00000000FFFF0000000000000000000000000000000000000000000000000000;
uint256 constant DISTRIBUTION_FACTOR_MASK =       0x0000FFFF00000000000000000000000000000000000000000000000000000000;

// forgefmt: disable-end

// Word 1
uint8 constant ADJUSTED_PROFIT_MARGIN_SHIFT = 0;
uint8 constant MINIMUM_KINK_RATE_SHIFT = 96;
uint8 constant ADJUSTED_ABOVE_KINK_SLOPE_SHIFT = 96 + 96;
uint8 constant MINIMUM_ABOVE_KINK_SLOPE_SHIFT = 96 + 96 + 24;
uint8 constant ADJUSTED_RESERVE_FACTOR_SHIFT = 96 + 96 + 24 + 24;

// Word 2
uint8 constant MINIMUM_RESERVE_FACTOR_SHIFT = 0;
uint8 constant ADJUSTED_BASE_RATE_SHIFT = 16;
uint8 constant MINIMUM_BASE_RATE_SHIFT = 16 + 96;
uint8 constant OPTIMAL_UTILIZATION_SHIFT = 16 + 96 + 96;
uint8 constant DISTRIBUTION_FACTOR_SHIFT = 16 + 96 + 96 + 16;

uint48 constant SECONDS_IN_A_YEAR = 31_536_000;

contract InterestRate {
    using RoundedMath for *;

    error CollateralIndexOutOfBounds();
    error DistributionFactorsDoNotSumToOne(uint256 sum);
    error TotalDebtsLength(uint256 collateralCount, uint256 totalIlkDebtsLength);

    /**
     * @dev Packed collateral configs
     */
    uint256 internal immutable ILKCONFIG_0A;
    uint256 internal immutable ILKCONFIG_0B;
    uint256 internal immutable ILKCONFIG_1A;
    uint256 internal immutable ILKCONFIG_1B;
    uint256 internal immutable ILKCONFIG_2A;
    uint256 internal immutable ILKCONFIG_2B;
    uint256 internal immutable ILKCONFIG_3A;
    uint256 internal immutable ILKCONFIG_3B;
    uint256 internal immutable ILKCONFIG_4A;
    uint256 internal immutable ILKCONFIG_4B;
    uint256 internal immutable ILKCONFIG_5A;
    uint256 internal immutable ILKCONFIG_5B;
    uint256 internal immutable ILKCONFIG_6A;
    uint256 internal immutable ILKCONFIG_6B;
    uint256 internal immutable ILKCONFIG_7A;
    uint256 internal immutable ILKCONFIG_7B;

    uint256 public immutable collateralCount;
    IYieldOracle immutable apyOracle;

    constructor(IlkData[] memory ilkDataList, IYieldOracle _apyOracle) {
        collateralCount = ilkDataList.length;
        apyOracle = _apyOracle;

        uint256 distributionFactorSum = 0;
        for (uint256 i = 0; i < collateralCount;) {
            distributionFactorSum += ilkDataList[i].distributionFactor;

            // forgefmt: disable-next-line
            unchecked { ++i; }
        }

        if (distributionFactorSum != 1e4) revert DistributionFactorsDoNotSumToOne(distributionFactorSum);

        (ILKCONFIG_0A, ILKCONFIG_0B) = _packCollateralConfig(ilkDataList, 0);
        (ILKCONFIG_1A, ILKCONFIG_1B) = _packCollateralConfig(ilkDataList, 1);
        (ILKCONFIG_2A, ILKCONFIG_2B) = _packCollateralConfig(ilkDataList, 2);
        (ILKCONFIG_3A, ILKCONFIG_3B) = _packCollateralConfig(ilkDataList, 3);
        (ILKCONFIG_4A, ILKCONFIG_4B) = _packCollateralConfig(ilkDataList, 4);
        (ILKCONFIG_5A, ILKCONFIG_5B) = _packCollateralConfig(ilkDataList, 5);
        (ILKCONFIG_6A, ILKCONFIG_6B) = _packCollateralConfig(ilkDataList, 6);
        (ILKCONFIG_7A, ILKCONFIG_7B) = _packCollateralConfig(ilkDataList, 7);
    }

    function _packCollateralConfig(
        IlkData[] memory ilkDataList,
        uint256 index
    )
        internal
        view
        returns (uint256 packedConfig_a, uint256 packedConfig_b)
    {
        if (index >= collateralCount) return (0, 0);

        IlkData memory ilkData = ilkDataList[index];

        packedConfig_a = (
            uint256(ilkData.adjustedProfitMargin) << ADJUSTED_PROFIT_MARGIN_SHIFT
                | uint256(ilkData.minimumKinkRate) << MINIMUM_KINK_RATE_SHIFT
                | uint256(ilkData.adjustedAboveKinkSlope) << ADJUSTED_ABOVE_KINK_SLOPE_SHIFT
                | uint256(ilkData.minimumAboveKinkSlope) << MINIMUM_ABOVE_KINK_SLOPE_SHIFT
                | uint256(ilkData.adjustedReserveFactor) << ADJUSTED_RESERVE_FACTOR_SHIFT
        );

        packedConfig_b = (
            uint256(ilkData.minimumReserveFactor) << MINIMUM_RESERVE_FACTOR_SHIFT
                | uint256(ilkData.adjustedBaseRate) << ADJUSTED_BASE_RATE_SHIFT
                | uint256(ilkData.minimumBaseRate) << MINIMUM_BASE_RATE_SHIFT
                | uint256(ilkData.optimalUtilizationRate) << OPTIMAL_UTILIZATION_SHIFT
                | uint256(ilkData.distributionFactor) << DISTRIBUTION_FACTOR_SHIFT
        );
    }

    function _unpackCollateralConfig(uint256 index) internal view returns (IlkData memory ilkData) {
        if (index > collateralCount - 1) revert CollateralIndexOutOfBounds();

        uint256 packedConfig_a;
        uint256 packedConfig_b;

        if (index == 0) {
            packedConfig_a = ILKCONFIG_0A;
            packedConfig_b = ILKCONFIG_0B;
        } else if (index == 1) {
            packedConfig_a = ILKCONFIG_1A;
            packedConfig_b = ILKCONFIG_1B;
        } else if (index == 2) {
            packedConfig_a = ILKCONFIG_2A;
            packedConfig_b = ILKCONFIG_2B;
        } else if (index == 3) {
            packedConfig_a = ILKCONFIG_3A;
            packedConfig_b = ILKCONFIG_3B;
        } else if (index == 4) {
            packedConfig_a = ILKCONFIG_4A;
            packedConfig_b = ILKCONFIG_4B;
        } else if (index == 5) {
            packedConfig_a = ILKCONFIG_5A;
            packedConfig_b = ILKCONFIG_5B;
        } else if (index == 6) {
            packedConfig_a = ILKCONFIG_6A;
            packedConfig_b = ILKCONFIG_6B;
        } else if (index == 7) {
            packedConfig_a = ILKCONFIG_7A;
            packedConfig_b = ILKCONFIG_7B;
        }

        uint72 adjustedProfitMargin =
            uint72((packedConfig_a & ADJUSTED_PROFIT_MARGIN_MASK) >> ADJUSTED_PROFIT_MARGIN_SHIFT);
        uint72 minimumKinkRate = uint72((packedConfig_a & MINIMUM_KINK_RATE_MASK) >> MINIMUM_KINK_RATE_SHIFT);
        uint24 adjustedAboveKinkSlope =
            uint24((packedConfig_a & ADJUSTED_ABOVE_KINK_SLOPE_MASK) >> ADJUSTED_ABOVE_KINK_SLOPE_SHIFT);
        uint24 minimumAboveKinkSlope =
            uint24((packedConfig_a & MINIMUM_ABOVE_KINK_SLOPE_MASK) >> MINIMUM_ABOVE_KINK_SLOPE_SHIFT);
        uint16 adjustedReserveFactor =
            uint16((packedConfig_a & ADJUSTED_RESERVE_FACTOR_MASK) >> ADJUSTED_RESERVE_FACTOR_SHIFT);

        uint16 minimumReserveFactor =
            uint16((packedConfig_b & MINIMUM_RESERVE_FACTOR_MASK) >> MINIMUM_RESERVE_FACTOR_SHIFT);
        uint72 adjustedBaseRate = uint72((packedConfig_b & ADJUSTED_BASE_RATE_MASK) >> ADJUSTED_BASE_RATE_SHIFT);
        uint72 minimumBaseRate = uint72((packedConfig_b & MINIMUM_BASE_RATE_MASK) >> MINIMUM_BASE_RATE_SHIFT);
        uint16 optimalUtilizationRate = uint16((packedConfig_b & OPTIMAL_UTILIZATION_MASK) >> OPTIMAL_UTILIZATION_SHIFT);
        uint16 distributionFactor = uint16((packedConfig_b & DISTRIBUTION_FACTOR_MASK) >> DISTRIBUTION_FACTOR_SHIFT);

        ilkData = IlkData({
            adjustedProfitMargin: adjustedProfitMargin,
            minimumKinkRate: minimumKinkRate,
            adjustedAboveKinkSlope: adjustedAboveKinkSlope,
            minimumAboveKinkSlope: minimumAboveKinkSlope,
            adjustedReserveFactor: adjustedReserveFactor,
            minimumReserveFactor: minimumReserveFactor,
            adjustedBaseRate: adjustedBaseRate,
            minimumBaseRate: minimumBaseRate,
            optimalUtilizationRate: optimalUtilizationRate,
            distributionFactor: distributionFactor
        });
    }

    /**
     * @param ilkIndex index of the collateral
     * @param totalIlkDebt total debt of the collateral (45 decimals)
     * @param totalEthSupply total eth supply of the system (18 decimals)
     */
    function calculateInterestRate(
        uint256 ilkIndex,
        uint256 totalIlkDebt, // [RAD]
        uint256 totalEthSupply
    )
        external
        view
        returns (uint256, uint256)
    {
        IlkData memory ilkData = _unpackCollateralConfig(ilkIndex);

        uint256 optimalUtilizationRateRay = ilkData.optimalUtilizationRate.scaleUpToRay(4);
        uint256 collateralApyRayInSeconds = apyOracle.apys(ilkIndex).scaleUpToRay(8) / SECONDS_IN_A_YEAR;

        // [RAD] / [WAD] = [RAY]
        uint256 utilizationRate =
        // Prevent division by 0
        totalEthSupply == 0 ? 0 : totalIlkDebt / (totalEthSupply.wadMulDown(ilkData.distributionFactor.scaleUpToWad(4))); 

        // Avoid stack too deep
        uint256 adjustedBelowKinkSlope;
        {
            uint256 slopeNumerator;
            unchecked {
                slopeNumerator = collateralApyRayInSeconds - ilkData.adjustedProfitMargin - ilkData.adjustedBaseRate;
            }

            // Underflow occured
            if (slopeNumerator > collateralApyRayInSeconds) {
                slopeNumerator = 0;
            }

            adjustedBelowKinkSlope = slopeNumerator.rayDivDown(optimalUtilizationRateRay);
        }

        uint256 minimumBelowKinkSlope =
            (ilkData.minimumKinkRate - ilkData.minimumBaseRate).rayDivDown(optimalUtilizationRateRay);

        if (utilizationRate < optimalUtilizationRateRay) {
            uint256 adjustedBorrowRate = adjustedBelowKinkSlope.rayMulDown(utilizationRate) + ilkData.adjustedBaseRate;
            uint256 minimumBorrowRate = minimumBelowKinkSlope.rayMulDown(utilizationRate) + ilkData.minimumBaseRate;

            if (adjustedBorrowRate < minimumBorrowRate) {
                console.log("branching min", minimumBorrowRate);
                return (minimumBorrowRate, ilkData.minimumReserveFactor.scaleUpToRay(4));
            } else {
                console.log("branching adj", adjustedBorrowRate);
                return (adjustedBorrowRate, ilkData.adjustedReserveFactor.scaleUpToRay(4));
            }
        } else {
            uint256 excessUtil = utilizationRate - optimalUtilizationRateRay;

            uint256 adjustedNormalRate =
                adjustedBelowKinkSlope.rayMulDown(optimalUtilizationRateRay) + ilkData.adjustedBaseRate;
            uint256 minimumNormalRate =
                minimumBelowKinkSlope.rayMulDown(optimalUtilizationRateRay) + ilkData.minimumBaseRate;

            // [WAD] * [RAY] / [WAD] = [RAY]
            uint256 adjustedBorrowRate =
                ilkData.adjustedAboveKinkSlope.scaleUpToWad(4).wadMulDown(excessUtil) + adjustedNormalRate;
            uint256 minimumBorrowRate =
                ilkData.minimumAboveKinkSlope.scaleUpToWad(4).wadMulDown(excessUtil) + minimumNormalRate;

            if (adjustedBorrowRate < minimumBorrowRate) {
                return (minimumBorrowRate, ilkData.minimumReserveFactor.scaleUpToRay(4));
            } else {
                return (adjustedBorrowRate, ilkData.adjustedReserveFactor.scaleUpToRay(4));
            }
        }
    }
}

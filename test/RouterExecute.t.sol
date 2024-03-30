// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Deployers} from "./utils/Deployers.sol";
import {RouterBaseTest} from "../src/test/RouterBaseTest.sol";

contract TruglyUniversalRouterExecuteTest is Deployers {
    /// @notice Test the execute function for a V3 Swap In with creator fees
    /// @dev From this TX: https://basescan.org/tx/0x76967c6c9f233537748b1869fbcd42af3f21a214c0c789c2cc321efaec4b3f97
    function test_execute_creator_success() public {
        (
            bytes memory commands,
            bytes[] memory inputs,
            uint256 deadline,
            uint256 amount,
            RouterBaseTest.ExpectedBalances memory expectedBalances
        ) = initSwapParams();
        routerBaseTest.execute{value: amount}(commands, inputs, deadline, expectedBalances);
    }

    //     /// @notice Test the execute function for a V3 Swap In with noCreator fees
    //     /// @dev From this TX: https://etherscan.io/tx/0xb1c329f334219c82a025ecc05a9ad46298b074f8cefdea6c9e1cf8ed1e1254b2
    //     function test_execute_noCreator_success() public {
    //         bytes memory commands = hex"0b000604";
    //         bytes[] memory inputs = new bytes[](4);
    //         inputs[0] =
    //             hex"000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000014d1120d7b160000";
    //         inputs[1] =
    //             hex"000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000014d1120d7b160000000000000000000000000000000000000000000020b64f99b7956fab772a8f8400000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002bc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2002710b9f599ce614feb2e1bbe58f180f370d05b39344e000000000000000000000000000000000000000000";
    //         inputs[2] =
    //             hex"000000000000000000000000b9f599ce614feb2e1bbe58f180f370d05b39344e0000000000000000000000000804a74cb85d6be474a4498fce76481822adffa40000000000000000000000000000000000000000000000000000000000000064";
    //         inputs[3] =
    //             hex"000000000000000000000000b9f599ce614feb2e1bbe58f180f370d05b39344e0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000020b64f99b7956fab772a8f84";
    //         uint256 deadline = 1708664855;

    //         uint256 amount = 1.5 ether;

    //         RouterBaseTest.ExpectedBalances memory expectedBalances = RouterBaseTest.ExpectedBalances({
    //             token0: address(0),
    //             token1: 0xb9f599ce614Feb2e1BBe58F180F370D05b39344E,
    //             creator: 0x17CC6042605381c158D2adab487434Bde79Aa61C,
    //             userDelta0: -1.5 ether,
    //             userDelta1: 10222674670720999505308675399,
    //             treasuryDelta0: 0,
    //             treasuryDelta1: 103259340108292924296047225,
    //             creatorDelta0: 0,
    //             creatorDelta1: 0
    //         });

    //         routerBaseTest.execute{value: amount}(commands, inputs, deadline, expectedBalances);
    //     }
}

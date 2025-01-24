// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

uint8 constant MAX_MEMBERS = 32;
uint256 constant CMT_BYTELEN = 32;
uint256 constant SIGNATURE_LEN = 160;
uint256 constant MIN_TARGET_CALLDATA_LEN = 56;

string constant SEMAPHORE_MSA_VALIDATOR = "SemaphoreMSAValidator";
string constant SEMAPHORE_MSA_EXECUTOR = "SemaphoreMSAExecutor";
string constant VERSION = "0.1.0";

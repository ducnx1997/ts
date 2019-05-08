pragma solidity >=0.4.22 <0.6.0;

contract MLPlatform {
    struct ModelVerificationInfo {
        address payable verificator;
        bytes32 modelHash;
        bytes32 resultIPFSHash;
        uint accuracy;
    }

    struct ModelInfo {
        address payable owner;
        bytes32 problemHash;
        bytes32 modelIPFSHash;
        bytes32[] verifications;
        uint numberOfOKVotes;
    }

    struct ProblemInfo {
        address payable owner;
        string statement;
        string dataIPFSHash;
        bytes32[] models;
        bytes32[] acceptableModels;
        uint requiredAccuracy;
        uint verificatorsNeededPerModel;
        uint totalRewards;
        bool completed;
    }

    uint nonce; // for hash generator
    address payable owner;
    mapping(bytes32 => ProblemInfo) problemInfo;
    mapping(bytes32 => ModelInfo) modelInfo;
    mapping(bytes32 => ModelVerificationInfo) modelVerificationInfo;

    // Purpose: Constructor. Set contract owner and initialize nonce value
    constructor() public {
        owner = msg.sender;
        nonce = 0;
    }

    // Purpose: For originators to submit problem information
    // Inputs:
    //  statement: Problem statement
    //
    function submitProblem(string memory statement,
                           string memory dataIPFSHash,
                           uint requiredAccuracy,
                           uint verificatorsNeededPerModel
                           ) public payable returns (bytes32 problemHash) {
       bytes32 hash = generateHash(msg.sig);
       problemInfo[hash].statement = statement;
       problemInfo[hash].dataIPFSHash = dataIPFSHash;
       problemInfo[hash].requiredAccuracy = requiredAccuracy;
       problemInfo[hash].verificatorsNeededPerModel = verificatorsNeededPerModel;
       problemInfo[hash].totalRewards = msg.value;
       problemInfo[hash].completed = false;
       delete problemInfo[hash].models;
       delete problemInfo[hash].acceptableModels;
       problemInfo[hash].owner = msg.sender;

       return hash;
    }

    // Purpose: For model owners to submit model information
    function submitModel(bytes32 problemHash, bytes32 modelIPFSHash)
                         public returns (bytes32 modelHash) {
        if (problemInfo[problemHash].completed) {
            return 0;
        }

        bytes32 hash = generateHash(msg.sig);
        problemInfo[problemHash].models.push(hash);
        modelInfo[hash].problemHash = problemHash;
        modelInfo[hash].modelIPFSHash = modelIPFSHash;
        modelInfo[hash].numberOfOKVotes = 0;
        delete modelInfo[hash].verifications;
        modelInfo[hash].owner = msg.sender;

        return hash;
    }

    // Purpose: For verificators to submit verification information
    function submitModelVerification(bytes32 modelHash,
                                     bytes32 resultIPFSHash,
                                     uint accuracy)
                                     public returns (bytes32 verifHash) {
        bytes32 problemHash = modelInfo[modelHash].problemHash;

        if (problemInfo[problemHash].completed ||
            modelInfo[modelHash].verifications.length ==
            problemInfo[problemHash].verificatorsNeededPerModel) {
            return 0;
        }

        bytes32 hash = generateHash(msg.sig);
        modelInfo[modelHash].verifications.push(hash);
        modelVerificationInfo[hash].modelHash = modelHash;
        modelVerificationInfo[hash].resultIPFSHash = resultIPFSHash;
        modelVerificationInfo[hash].accuracy = accuracy;
        modelVerificationInfo[hash].verificator = msg.sender;

        if (accuracy >= problemInfo[problemHash].requiredAccuracy) {
            ++modelInfo[modelHash].numberOfOKVotes;
        }

        if (modelInfo[modelHash].verifications.length ==
            problemInfo[problemHash].verificatorsNeededPerModel &&
            modelInfo[modelHash].numberOfOKVotes >=
            problemInfo[problemHash].verificatorsNeededPerModel * 60 / 100) {
            problemInfo[problemHash].acceptableModels.push(modelHash);
        }

        return hash;
    }

    // Purpose: Generate a random hash using Keccak256
    function generateHash(bytes32 data) private returns (bytes32) {
        return keccak256(abi.encodePacked(blockhash(block.number), data, nonce++));
    }

    // Purpose: Get general problem info
    function getProblemInfo(bytes32 hash) public view returns
                           (string memory statement,
                            uint requiredAccuracy,
                            uint totalRewards,
                            bool completed) {
        return (problemInfo[hash].statement,
                problemInfo[hash].requiredAccuracy,
                problemInfo[hash].totalRewards,
                problemInfo[hash].completed);
    }

    // Purpose: Mark the problem as completed and reward contributors
    function completeProblem(bytes32 hash) public {
        if (msg.sender != problemInfo[hash].owner ||
            problemInfo[hash].completed) {
            return;
        }

        problemInfo[hash].completed = true;

        if (problemInfo[hash].acceptableModels.length > 0) {
            uint rewardsForModelOwners = problemInfo[hash].totalRewards * 70 / 100;
            uint rewardsForVerificators = problemInfo[hash].totalRewards - rewardsForModelOwners;

            for (uint i = 0; i < problemInfo[hash].acceptableModels.length; ++i) {
                bytes32 modelHash = problemInfo[hash].acceptableModels[i];
                modelInfo[modelHash].owner.transfer(
                    rewardsForModelOwners / problemInfo[hash].acceptableModels.length);

                for (uint j = 0; j < modelInfo[modelHash].verifications.length; ++j) {
                    bytes32 verifHash = modelInfo[modelHash].verifications[j];
                    modelVerificationInfo[verifHash].verificator.transfer(
                        rewardsForVerificators / problemInfo[hash].verificatorsNeededPerModel);
                }
            }
        } else {
            problemInfo[hash].owner.transfer(problemInfo[hash].totalRewards);
        }
    }

    // Purpose: Get all models hashes for a problem
    function getModels(bytes32 problemHash) public view returns (bytes32[] memory models) {
        if (msg.sender != problemInfo[problemHash].owner || !problemInfo[problemHash].completed) {
            return new bytes32[](0);
        }

        return problemInfo[problemHash].models;
    }

    // Purpose: Get all verifications hashes for a model
    function getModelVerifications(bytes32 modelHash) public view returns (bytes32[] memory verifications) {
        bytes32 problemHash = modelInfo[modelHash].problemHash;

        if (msg.sender != problemInfo[problemHash].owner || !problemInfo[problemHash].completed) {
            return new bytes32[](0);
        }

        return modelInfo[modelHash].verifications;
    }

    // Purpose: Get verification result
    function getVerificationResult(bytes32 verifHash) public view returns (bytes32 resultIPFSHash, uint accuracy) {
        bytes32 modelHash = modelVerificationInfo[verifHash].modelHash;
        bytes32 problemHash = modelInfo[modelHash].problemHash;

        if (msg.sender != problemInfo[problemHash].owner || !problemInfo[problemHash].completed) {
            return (0, 0);
        }

        return (modelVerificationInfo[verifHash].resultIPFSHash, modelVerificationInfo[verifHash].accuracy);
    }

    // function getRandomModel() public view returns (bytes32 modelHash, bytes32 dataIPFSHash) {
    //     bytes32 problemHash = getRandomKey(problemInfo);
    //     bytes32 modelHash = getRandomElement(problemHash[problemInfo].models);

    //     return (modelHash, problemInfo[problemHash].dataIPFSHash);
    // }
}

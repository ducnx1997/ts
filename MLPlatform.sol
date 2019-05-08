pragma solidity >=0.4.22 <0.6.0;
pragma experimental ABIEncoderV2;

contract MLPlatform {
    struct Evaluation {
        address payable author;
        uint accuracy;
    }
    
    struct Model {
        address payable author;
        bytes32 taskId;
        string modelIPFSHash;
        Evaluation[] evaluations;
        uint numberOfTrueEvaluation;
        uint accuracy;
    }
    
    struct Task {
        address payable owner;
        string description;
        string datasetIPFSHash;
        string suggestedModelIPFSHash;
        bytes32[] modelIds;
        bytes32[] acceptedModelIds;
        uint dueDate;
        uint requiredAccuracy;
        uint requiredNumVerifications;
        uint minAcceptedRate;
        uint reward;
        uint rewardRatio;
        bool completed;
    }
    
    uint nonce;
    address payable owner;
    mapping(bytes32 => Task) tasks;
    bytes32[] taskIds;
    
    mapping(bytes32 => Model) models;
    bytes32[] modelIds;
    
    mapping(bytes32 => Evaluation) evaluations;   

    constructor() public {
        owner = msg.sender;
        nonce = 0;
    }
    
    function submitProblem(string memory description,
                           string memory datasetIPFSHash,
                           string memory suggestedModelIPFSHash,
                           uint dueDate,
                           uint requiredAccuracy,
                           uint requiredNumVerifications,
                           uint minAcceptedRate,
                           uint rewardRatio
                           ) public payable returns (bytes32 taskId) {
       bytes32 id = generateHash(msg.sig);
       Task storage task = tasks[id];
       task.description = description;
       task.datasetIPFSHash = datasetIPFSHash;
       task.suggestedModelIPFSHash = suggestedModelIPFSHash;
       task.requiredAccuracy = requiredAccuracy;
       task.requiredNumVerifications = requiredNumVerifications;
       task.reward = msg.value;
       task.dueDate = dueDate;
       task.rewardRatio = rewardRatio;
       task.completed = false;
       task.minAcceptedRate = minAcceptedRate;
       delete task.modelIds;
       delete task.acceptedModelIds;
       task.owner = msg.sender;

       taskIds.push(id);
       
       return id;
    }
    
    function submitModel(bytes32 taskId, string memory modelIPFSHash)
                         public returns (bytes32 modelId) {
        if (tasks[taskId].completed || now > tasks[taskId].dueDate) {
            return 0;
        }
        
        bytes32 id = generateHash(msg.sig);
        modelIds.push(id);
        tasks[taskId].modelIds.push(id);
        models[id].taskId = taskId;
        models[id].modelIPFSHash = modelIPFSHash;
        models[id].numberOfTrueEvaluation = 0;
        delete models[id].evaluations;
        models[id].author = msg.sender;
        
        return id;
    }
    
    function receiveModels(bytes32 id) public view returns(bytes32[] memory acceptableModelIds, string memory details) {
        Task storage task = tasks[id];
        
        // if (now < task.dueDate) {
        //     return (new bytes32[](0), '');
        // }
        
        require(msg.sender == task.owner, "Only task's owner can do it.");
        
        if (!task.completed) {
            return (new bytes32[](0), 'You need to send reward first.'); 
        }
        
        string memory result = '';
        
        for (uint i = 0; i < task.acceptedModelIds.length; ++i) {
            result = concate(result, '<model>');
            
            result = concate(result, '<accuracy>');
            result = concate(result, uint2str(models[task.acceptedModelIds[i]].accuracy));
            result = concate(result, '</accuracy>');
            
            
            result = concate(result, '<modelIPFSHash>');
            result = concate(result, models[task.acceptedModelIds[i]].modelIPFSHash);
            result = concate(result, '</modelIPFSHash>');

            result = concate(result, '</model>');
        }
        
        return (task.acceptedModelIds, result);
    }
    
    function submitModelVerification(bytes32 modelId, uint accuracy) 
                                     public returns (bool ok) {
        bytes32 taskId = models[modelId].taskId;
        
        if (tasks[taskId].completed || 
            models[modelId].evaluations.length >= tasks[taskId].requiredNumVerifications) {
            return false;
        }
        
        bytes32 id = generateHash(msg.sig);
        evaluations[id].author = msg.sender;
        evaluations[id].accuracy = accuracy;
        
        models[modelId].evaluations.push(evaluations[id]);
        
        return true;
    }

    function getRandomVerificationTask() public view 
            returns (bytes32 modelId, string memory modelIPFSHash, string memory datasetIPFSHash) {
        if (modelIds.length == 0) return (0, uint2str(modelIds.length), '');

        for (uint i = 0; i < 10; ++i) {
            uint randomNumber = random(modelIds.length);
            bytes32 _modelId = modelIds[randomNumber];

            Model storage model = models[_modelId];
            Task storage task = tasks[model.taskId];
            if (!task.completed && model.evaluations.length < task.requiredNumVerifications && now < task.dueDate) {
                return (_modelId, model.modelIPFSHash, task.datasetIPFSHash);
            }
        }
        
        return (0, '', '');
    }

    function getTask(bytes32 id) public view returns 
                           (string memory description,
                            uint dueDate,
                            uint requiredAccuracy, 
                            uint reward, 
                            uint rewardRatio,
                            string memory suggestedModelIPFSHash) {
        return (tasks[id].description, 
                tasks[id].dueDate,
                tasks[id].requiredAccuracy, 
                tasks[id].reward, 
                tasks[id].rewardRatio,
                tasks[id].suggestedModelIPFSHash);
    }

    function getTasks() public view returns (bytes32[] memory ids, string memory details) {
        string memory _taskDetails;
        for (uint i = 0; i < taskIds.length; ++i) {
            _taskDetails = concate(_taskDetails, '<task>');
            
            _taskDetails = concate(_taskDetails, '<description>');
            _taskDetails = concate(_taskDetails, tasks[taskIds[i]].description);
            _taskDetails = concate(_taskDetails, '</description>');
            
            
            _taskDetails = concate(_taskDetails, '<reward>');
            _taskDetails = concate(_taskDetails, uint2str(tasks[taskIds[i]].reward));
            _taskDetails = concate(_taskDetails, '</reward>');
            
            _taskDetails = concate(_taskDetails, '<dueDate>');
            _taskDetails = concate(_taskDetails,  uint2str(tasks[taskIds[i]].dueDate));
            _taskDetails = concate(_taskDetails, '</dueDate>');
            
            _taskDetails = concate(_taskDetails, '<completed>');
            if (tasks[taskIds[i]].completed) {
                _taskDetails = concate(_taskDetails,  'true');
            } else {
                _taskDetails = concate(_taskDetails,  'false');
            }
            
            _taskDetails = concate(_taskDetails, '</completed>');
            
            _taskDetails = concate(_taskDetails, '</task>');
        }
        
        return (taskIds, _taskDetails);
    }

    function sendRewards(bytes32 id) public {
        Task storage task = tasks[id];
        require(msg.sender == task.owner, "Only task's owner can do it.");
        
        if (msg.sender != task.owner || task.completed) {
            return;
        }
        
        uint totalNumOfTrueEvaluation = 0;
        
        for (uint i = 0; i < task.modelIds.length; ++i) {
            Model storage model = models[task.modelIds[i]];
            
            if (model.evaluations.length == 0) {
                continue;
            }
            
            uint[] memory values = new uint[](model.evaluations.length);
            uint[] memory counts = new uint[](model.evaluations.length);
            uint numUnique = 0;
            
            for (uint j = 0; j < model.evaluations.length; ++j) {
                Evaluation storage evaluation = model.evaluations[j];
                
                bool isDuplicate = false;
                
                for (uint k = 0; k < numUnique; ++k) {
                    if (values[k] == evaluation.accuracy) {
                        isDuplicate = true;
                        counts[k]++;
                        break;
                    }
                }
                
                if (!isDuplicate) {
                    values[numUnique] = evaluation.accuracy;
                    counts[numUnique] = 1;
                    numUnique++;
                }
            }
            
            uint maxCount = 0;
            uint finalAccuracy = 0;
            
            for (uint j = 0; j < numUnique; ++j) {
                if (counts[j] > maxCount) {
                    maxCount = counts[j];
                    finalAccuracy = values[j];
                }
            }
            
            if (maxCount * 2 >= model.evaluations.length) {
                model.accuracy = finalAccuracy;
                model.numberOfTrueEvaluation = maxCount;
                
                totalNumOfTrueEvaluation += maxCount;
                
                if (maxCount * 100 / model.evaluations.length >= task.minAcceptedRate && model.accuracy >= task.requiredAccuracy) {
                    task.acceptedModelIds.push(task.modelIds[i]);
                }
            }
        }
        
        
        uint rewardsForModelOwners = 
            task.reward * task.rewardRatio / 100;
        uint rewardsForVerificators = 
            task.reward - rewardsForModelOwners;
            
        
        if (task.acceptedModelIds.length > 0) {
            for (uint i = 0; i < task.acceptedModelIds.length; ++i) {
                Model storage model = models[task.acceptedModelIds[i]];
                model.author.transfer(
                    rewardsForModelOwners / task.acceptedModelIds.length);
            }
        } else {
            task.owner.transfer(rewardsForModelOwners);
        }
        
        if (totalNumOfTrueEvaluation > 0) {
            for (uint i = 0; i < task.modelIds.length; ++i) {
                Model storage model = models[task.modelIds[i]];
                for (uint j = 0; j < model.evaluations.length; ++j) {
                    Evaluation memory evaluation = model.evaluations[j];
                    if (evaluation.accuracy == model.accuracy) {
                        evaluation.author.transfer(
                            rewardsForVerificators / totalNumOfTrueEvaluation);
                    }
                }
            }
        } else {
            task.owner.transfer(rewardsForVerificators);
        }
            
        task.completed = true;
    }
    
    function concate(string memory a, string memory b) private pure returns(string memory) {
        return string(abi.encodePacked(a, b));
    }
    
    function generateHash(bytes32 data) private returns (bytes32) {
        return keccak256(abi.encodePacked(blockhash(block.number), data, nonce++));
    }
    
    function uint2str(uint _i) private pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (_i != 0) {
            bstr[k--] = byte(uint8(48 + _i % 10));
            _i /= 10;
        }
        return string(bstr);
    }

    function random(uint modNumber) private view returns (uint) {
        uint randomNumber = uint(keccak256(abi.encodePacked(now, msg.sender, block.difficulty))) % modNumber;
        return randomNumber;
    }
}

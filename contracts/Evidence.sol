pragma solidity ^0.8.20;

contract EvidenceManagementSystem {

    struct Evidence {
        uint256 id;
        string metadataHash; 
        address owner;       
        bool exists;
    }

    uint256 private _evidenceIds;
    mapping(uint256 => Evidence) private _evidences;
    mapping(uint256 => mapping(address => bool)) private _authorizedAccess;
    mapping(uint256 => mapping(address => bool)) private _hasRequested;


    event EvidenceCreated(uint256 indexed id, address indexed owner, string metadataHash);
    event AccessRequested(uint256 indexed id, address indexed requester);
    event AccessGranted(uint256 indexed id, address indexed authorizedUser);
    event OwnershipTransferred(uint256 indexed id, address indexed from, address indexed to);

    modifier onlyOwner(uint256 id) {
        require(_evidences[id].owner == msg.sender, "Not the evidence owner");
        _;
    }

    modifier hasPermission(uint256 id) {
        require(_evidences[id].exists, "Evidence does not exist");
        require(
            _evidences[id].owner == msg.sender || _authorizedAccess[id][msg.sender],
            "Access denied: No authorization"
        );
        _;
    }

    function create(string memory _metadataHash) public returns (uint256) {
        _evidenceIds++;
        uint256 newId = _evidenceIds;

        _evidences[newId] = Evidence({
            id: newId,
            metadataHash: _metadataHash,
            owner: msg.sender,
            exists: true
        });

        emit EvidenceCreated(newId, msg.sender, _metadataHash);
        return newId;
    }

 
    function read(uint256 id) public view hasPermission(id) returns (string memory) {
        return _evidences[id].metadataHash;
    }

    function transfer(uint256 id, address newCustodian) public onlyOwner(id) {
        require(newCustodian != address(0), "Cannot transfer to zero address");
        
        address oldCustodian = _evidences[id].owner;
        _evidences[id].owner = newCustodian;

        emit OwnershipTransferred(id, oldCustodian, newCustodian);
    }

    function requestAccess(uint256 id) public {
        require(_evidences[id].exists, "Evidence does not exist");
        _hasRequested[id][msg.sender] = true;
        emit AccessRequested(id, msg.sender);
    }

    function grantAccess(uint256 id, address authorizedUser) public onlyOwner(id) {
        require(_hasRequested[id][authorizedUser], "No request found for this address");
        
        _authorizedAccess[id][authorizedUser] = true;
        emit AccessGranted(id, authorizedUser);
    }

    function getOwner(uint256 id) public view returns (address) {
        return _evidences[id].owner;
    }
}

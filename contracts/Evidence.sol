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

    // --- Dashboard indexes ---
    // IDs currently owned by an address. Kept in sync on create()/transfer()
    // using swap-and-pop removal, so lookups and removal are both O(1).
    mapping(address => uint256[]) private _ownedIds;
    mapping(uint256 => uint256) private _ownedIdIndex; // id => index within _ownedIds[owner]

    // IDs an address has been granted read access to. Append-only: there is
    // no revokeAccess() in this contract, so once granted, always listed.
    mapping(address => uint256[]) private _accessibleIds;

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

        _addOwnedId(msg.sender, newId);

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

        _removeOwnedId(oldCustodian, id);
        _addOwnedId(newCustodian, id);

        emit OwnershipTransferred(id, oldCustodian, newCustodian);
    }

    function requestAccess(uint256 id) public {
        require(_evidences[id].exists, "Evidence does not exist");
        _hasRequested[id][msg.sender] = true;
        emit AccessRequested(id, msg.sender);
    }

    function grantAccess(uint256 id, address authorizedUser) public onlyOwner(id) {
        require(_hasRequested[id][authorizedUser], "No request found for this address");
        require(!_authorizedAccess[id][authorizedUser], "Already authorized");
        
        _authorizedAccess[id][authorizedUser] = true;
        _accessibleIds[authorizedUser].push(id);
        emit AccessGranted(id, authorizedUser);
    }

    function getOwner(uint256 id) public view returns (address) {
        return _evidences[id].owner;
    }

    /// @notice IDs of evidence currently owned by `account`.
    function getOwnedEvidence(address account) public view returns (uint256[] memory) {
        return _ownedIds[account];
    }

    /// @notice IDs of evidence `account` has been granted read access to.
    /// @dev May include IDs `account` currently owns (e.g. if access was
    ///      granted before a transfer back to them) — filter against
    ///      getOwnedEvidence() on the client if you need a strict "shared,
    ///      not owned" list.
    function getAccessibleEvidence(address account) public view returns (uint256[] memory) {
        return _accessibleIds[account];
    }

    function _addOwnedId(address owner, uint256 id) private {
        _ownedIds[owner].push(id);
        _ownedIdIndex[id] = _ownedIds[owner].length - 1;
    }

    function _removeOwnedId(address owner, uint256 id) private {
        uint256[] storage ids = _ownedIds[owner];
        uint256 idx = _ownedIdIndex[id];
        uint256 lastIdx = ids.length - 1;

        if (idx != lastIdx) {
            uint256 lastId = ids[lastIdx];
            ids[idx] = lastId;
            _ownedIdIndex[lastId] = idx;
        }

        ids.pop();
        delete _ownedIdIndex[id];
    }
}

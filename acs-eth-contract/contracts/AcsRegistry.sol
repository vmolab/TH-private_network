// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// import "@openzeppelin/contracts/access/Ownable.sol";

// contract AcsRegistry is Ownable {
contract AcsRegistry  {
    /*--------------------------------------------------------------------*\
     |  1. Struct definitions                                              |
    \*--------------------------------------------------------------------*/
    struct User {
        string id;       // 사용자 ID
        string name;     // 사용자 이름
        string did;      // 사용자 DID or None
        string[] role;     // 사용자 역할, e.g. "Provider", "Consumer", ...        
        string addr;     // 사용자 주소, e.g. "Jeju"
        string contact;  // 연락처: None or e‑mail, phone …
    }

    struct Data {
        string name;         // 데이터 이름
        uint256 size;        // 데이터 크기, bytes
        string owner;        // 소유자 ID
        string cid;          // IPFS에 저장된 데이터의 CID
        string encryption;   // AES‑256, none …
        string creation;     // 저장한 날짜
        string revision;     // 리비전 번호
        string metadata;     // 메타데이터: 기타 저장하고 싶은 데이터, JSON string
    }

    struct Role {
        string id;     // User's Role ID
        string name;   // ex) "admin", "researcher"
        // string cid;    // 해당 역할이 접근할 기본 데이터 세트
    }

    struct Permission {
        string id;    // = roleID + "_" + dataCID
        string list;  // CSV 또는 JSON 권한 세트
    }

    /*--------------------------------------------------------------------*\
     |  2. Storage                                                         |
    \*--------------------------------------------------------------------*/
    mapping(bytes32 => User)        private users;       // key = keccak256(id)
    mapping(bytes32 => Data)        private data;        // key = keccak256(cid)
    mapping(bytes32 => Role)        private roles;       // key = keccak256(id)
    mapping(bytes32 => Permission)  private perms;       // key = keccak256(id)

    /*--------------------------------------------------------------------*\
     |  3. Events                                                          |
    \*--------------------------------------------------------------------*/
    // User Events
    event UserRegistered(bytes32 indexed id);
    event UserUpdated(bytes32 indexed id);
    event UserDeleted(bytes32 indexed id);
    // Data Events
    event DataPut(bytes32 indexed cid);
    event DataUpdated(bytes32 indexed cid);
    event DataDeleted(bytes32 indexed cid);
    event DataTransferred(bytes32 indexed cid, string newOwner);
    // Role Events
    event RoleRegistered(bytes32 indexed id);
    event RoleUpdated(bytes32 indexed id);
    event RoleDeleted(bytes32 indexed id);
    event RoleGranted(bytes32 indexed id, string roleID);
    event RoleRevoked(bytes32 indexed id, string roleID);
    event PermissionGranted(bytes32 indexed id);
    event PermissionRevoked(bytes32 indexed id);

    /*--------------------------------------------------------------------*\
     |  4‑1.  User CRUD                                                    |
    \*--------------------------------------------------------------------*/
    
    // registerUser() registers a new user
    function registerUser(
        string calldata _userID,
        string calldata _userName,
        string calldata _userDID,
        string calldata _userRole,
        string calldata _userAddr,
        string calldata _userContact
    ) external /* onlyOwner */ {
        require(bytes(_userID).length > 0, "User ID cannot be empty");

        bytes32 key = keccak256(bytes(_userID));        
        require(bytes(users[key].id).length == 0, "User already exists");

        string[] memory userRole = new string[](1);
        userRole[0] = _userRole;
        
        users[key] = User(
            _userID, _userName, _userDID, userRole, _userAddr, _userContact
        );
        emit UserRegistered(key);
    }

    // getUser() returns user info as User struct
    function getUser(string calldata _userID)
        external view
        returns (User memory)
    {
        bytes32 key = keccak256(bytes(_userID));
        require(bytes(users[key].id).length != 0, "User not exists");
        
        return users[key];
    }

    // updateUser() updates user info
    function updateUser(
        string calldata _userID,
        string calldata _userName,
        string calldata _userDID,
        string calldata _userRole,
        string calldata _userAddr,
        string calldata _userContact
    ) external /* onlyOwner */ {
        require(bytes(_userID).length > 0, "User ID cannot be empty");
        
        bytes32 key = keccak256(bytes(_userID));
        require(bytes(users[key].id).length != 0, "User not exists");

        User storage user = users[key];

        if (bytes(_userName).length > 0) {
            user.name = _userName;
        }
        if (bytes(_userDID).length > 0) {
            user.did = _userDID;
        }
        // _userRole = "Provider" or "Consumer" represented as "Provider;Consumer"
       
        string[] storage role = users[key].role;
        // if it's the first role, assign it directly
        if (role.length == 0) {
            role.push(_userRole);           
        } else {
            // get existing roles and split them by ";"
            bool found = false;
            for (uint256 i = 0; i < role.length; i++) {
                if (keccak256(bytes(role[i])) != keccak256(bytes(_userRole))) {
                    found = true;
                    break;
                }
            } 
            
            if (found == false) {
                // if the role is not found, add it
                role.push(_userRole);
            }
        }
        
        
        if (bytes(_userAddr).length > 0) {
            user.addr = _userAddr;
        }

        if (bytes(_userContact).length > 0) {
            user.contact = _userContact;
        }

        emit UserUpdated(key);
    }
    
    // deleteUser() deletes user info
    function deleteUser(string calldata _userID) external /* onlyOwner */ {
        bytes32 key = keccak256(bytes(_userID));
        require(bytes(users[key].id).length != 0, "User not exists");

        delete users[key];
        emit UserDeleted(key);
    }

    /*--------------------------------------------------------------------*\
     |  4‑2.  Data CRUD                                                    |
    \*--------------------------------------------------------------------*/

    // putData() registers a new data
    function putData(
        string calldata _dataName,
        uint256 _dataSize,
        string calldata _dataOwner,
        string calldata _dataCID,
        string calldata _dataEncryption,
        string calldata _dataCreation,
        string calldata _dataRevision,
        string calldata _dataMeta
    ) external /* onlyOwner */ {
        bytes32 key = keccak256(bytes(_dataCID));
        require(bytes(data[key].cid).length == 0, "Data already exists");

        data[key] = Data(
            _dataName,
            _dataSize,
            _dataOwner,
            _dataCID,
            _dataEncryption,
            _dataCreation,
            _dataRevision,
            _dataMeta
        );
        emit DataPut(key);
    }

    // getData() returns data info as Data struct
    function getData(string calldata _dataCID)
        external view
        returns (Data memory)
    {
        bytes32 key = keccak256(bytes(_dataCID));
        require(bytes(data[key].cid).length != 0, "Data not exists");

        return data[key];
    }

    // updateData() updates data info
    function updateData(
        string calldata _dataOwner,
        string calldata _dataCID,
        string calldata _dataMeta
    ) external /* onlyOwner */ {
        bytes32 key = keccak256(bytes(_dataCID));        
        require(bytes(data[key].cid).length != 0, "Data not exists");

        bytes32 _owner = keccak256(bytes(_dataOwner));
        require(keccak256(bytes(data[key].owner)) == _owner, "Data owner mismatch");

        Data storage datum = data[key];

        // Only update metadata
        if (bytes(_dataMeta).length > 0) {
            datum.metadata = _dataMeta;
        }

        emit DataUpdated(key);
    }

    // deleteData() deletes data info
    function deleteData(string calldata _dataOwner, 
        string calldata _dataCID
    ) external /* onlyOwner */ {
        bytes32 key = keccak256(bytes(_dataCID));
        require(bytes(data[key].cid).length != 0, "Data not exists");

        bytes32 _owner = keccak256(bytes(_dataOwner));
        require(keccak256(bytes(data[key].owner)) == _owner, "Data owner mismatch");

        delete data[key];
        emit DataDeleted(key);
    }   

    // transferData() transfers data ownership
    function transferData(
        string calldata _dataOwner,
        string calldata _dataCID,
        string calldata _newOwner
    ) external /* onlyOwner */ {
        bytes32 key = keccak256(bytes(_dataCID));
        require(bytes(data[key].cid).length != 0, "Data not exists");

        bytes32 _owner = keccak256(bytes(_dataOwner));
        require(keccak256(bytes(data[key].owner)) == _owner, "Data owner mismatch");

        require(keccak256(bytes(_newOwner)).length != 0, "New owner not exists");

        data[key].owner = _newOwner;
        emit DataTransferred(key, _newOwner);
    }

    // getDataOwner() returns data owner
    function getDataOwner(string calldata _dataCID)
        external view
        returns (string memory)
    {
        bytes32 key = keccak256(bytes(_dataCID));
        require(bytes(data[key].cid).length != 0, "Data not exists");

        return data[key].owner;
    }

    /*--------------------------------------------------------------------*\
     |  4‑3.  Role CRUD                                                    |
    \*--------------------------------------------------------------------*/

    // registerRole() registers a new role
    function registerRole(
        string calldata _roleID,
        string calldata _roleName
    ) external /* onlyOwner */ {
        bytes32 key = keccak256(bytes(_roleID));
        require(bytes(roles[key].id).length == 0, "Role already exists");

        roles[key] = Role(_roleID, _roleName);
        emit RoleRegistered(key);
    }

    // getRole() returns role info as Role struct
    function getRole(string calldata _roleID)
        external view
        returns (Role memory)
    {
        bytes32 key = keccak256(bytes(_roleID));
        require(bytes(roles[key].id).length != 0, "Role not exists");

        return roles[key];
    }

    // updateRole() updates role info
    function updateRole(
        string calldata _roleID,
        string calldata _roleName
    ) external /* onlyOwner */ {
        bytes32 key = keccak256(bytes(_roleID));
        require(bytes(roles[key].id).length != 0, "Role not exists");

        roles[key].name = _roleName;
        emit RoleUpdated(key);
    }

    // deleteRole() deletes a role
    function deleteRole(string calldata _roleID) external /* onlyOwner */ {
        bytes32 key = keccak256(bytes(_roleID));
        require(bytes(roles[key].id).length != 0, "Role not exists");
        
        delete roles[key];
        emit RoleDeleted(key);
    }

    // grantRole() grants a role to a user
    function grantRole(
        string calldata _userID,
        string calldata _roleID
    ) external /* onlyOwner */ {
        bytes32 key = keccak256(bytes(_userID));
        require(bytes(users[key].id).length != 0, "User not exists");

        string[] storage role = users[key].role;
        // if it's the first role, assign it directly
        if (role.length == 0) {
            role.push(_roleID);           
        } else {
            // get existing roles and split them by ";"
            for (uint256 i = 0; i < role.length; i++) {
                require(keccak256(bytes(role[i])) != keccak256(bytes(_roleID)), "Role already granted");
            } 
            role.push(_roleID);
        }
       
        emit RoleGranted(key, _roleID);
    }

    function revokeRole(
        string calldata _userID,
        string calldata _roleID
    ) external /* onlyOwner */ {
        bytes32 key = keccak256(bytes(_userID));
        require(bytes(users[key].id).length != 0, "User not exists");

        string[] storage role = users[key].role;
        if (role.length == 0) {
            revert("No role assigned");
        } else {
            // get existing role and delete it
            for (uint256 i = 0; i < role.length; i++) {
                if (keccak256(bytes(role[i])) == keccak256(bytes(_roleID))) {
                    // remove the role from the list
                    role[i] = role[role.length - 1];
                    role.pop();
                    break;
                }
            }            
        }

        emit RoleRevoked(key, _roleID);
    }

    /*--------------------------------------------------------------------*\
     |  4‑4.  Permission CRUD                                              |
    \*--------------------------------------------------------------------*/

    // grantPermission() registers a new permission
    function grantPermission(
        string calldata _permissionID,
        string calldata _permissionList
    ) external /* onlyOwner */ {
        bytes32 key = keccak256(bytes(_permissionID));
        require(bytes(perms[key].id).length == 0, "Permission exists");

        perms[key] = Permission(_permissionID, _permissionList);
        emit PermissionGranted(key);
    }

    // getPermission() returns permission info as Permission struct
    function getPermission(string calldata _permissionID)
        external view
        returns (Permission memory)
    {
        bytes32 key = keccak256(bytes(_permissionID));
        return perms[key];
    }

    // revokePermission() deletes a permission
    function revokePermission(string calldata _permissionID) external /* onlyOwner */ {
        bytes32 key = keccak256(bytes(_permissionID));
        require(bytes(perms[key].id).length != 0, "Permission not exists");

        delete perms[key];
        emit PermissionRevoked(key);
    }
}
pragma solidity ^0.5.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./StandardToken.sol";

/**
 * @dev Extension of `ERC20` that allows an owner to create certificates
 * to allow users to redeem/mint their own tokens according to certificate parameters
 */
contract ERC20Certificate is StandardToken, Ownable  {

    using ECDSA for bytes32;
    using SafeMath for uint256;

    mapping (bytes32 => certificateType) public certificateTypes;
    mapping (address => bool) public condenserDelegates;

    struct certificateType {
        uint256 amount;
        string metadata;
        mapping (address => bool) delegates;
        mapping (address => bool) claimed;
    }

    /**
     * @dev Creates a certificate type where users can redeem the certificate
     * to receive `_amount` of tokens. Any of the `_delegates` can sign a certificate
     * for a given address.
     *
     * `_metadata` field is meant to be an IPFS hash or URI which will
     * resolve to display unique information about a particular certificate
     *
     * Can only be called by owner of contract
     *
     * Emits a `CertificateTypeCreated` event.
     */
    function createCertificateType(uint256 _amount, address[] calldata _delegates, string calldata _metadata) external onlyOwner {
        bytes32 certID = _getCertificateID(_amount, _delegates, _metadata);
        certificateTypes[certID].amount = _amount;
        certificateTypes[certID].metadata = _metadata;

        for (uint8 i = 0; i < _delegates.length; i++) {
            certificateTypes[certID].delegates[_delegates[i]] = true;
        }
        emit CertificateTypeCreated(certID, _amount, _delegates);
    }

    /**
     * @dev Allows owner to add a trusted address as a condenser delegate.
     * Any address added to this mapping will be able to sign condensed certificates
     */
    function addCondenserDelegate(address _delegate) external onlyOwner {
        condenserDelegates[_delegate] = true;
    }
    
    /**
     * @dev Allows owner to remove an address from the condenser delegate mapping.
     */
    function removeCondenserDelegate(address _delegate) external onlyOwner {
        condenserDelegates[_delegate] = false;
    }


    /**
     * @dev Allows caller to pass a `_signature` and a `_certificateID` to
     * mint tokens to their own address. The token amount minted is speficied in the
     * certificate. Can only be called once per caller, per certificate
     *
     * Emits a `CertificateRedeemed` event.
     */
    function redeemCertificate(bytes calldata _signature, bytes32 _certificateID) external
        returns (bool)
    {
        bytes32 hash = _getCertificateHash(_certificateID, msg.sender);
        require(_isDelegateSigned(hash, _signature, _certificateID), "Not Delegate Signed");
        require(!certificateTypes[_certificateID].claimed[msg.sender], "Cert already claimed");

        certificateTypes[_certificateID].claimed[msg.sender] = true;
        uint256 amount = certificateTypes[_certificateID].amount;
        _mint(msg.sender, amount);
        emit CertificateRedeemed(msg.sender, amount, _certificateID);
        return true;
    }

    /**
     * @dev Allows caller to pass an `_signature`, a `_combinedValue` and a list of `_certificateIDs` to
     * redeem a condensed certificate which has the summed value of each certificate in the list.
     * This will fail if any of the certificates in the list has already been redeemed
     *
     * Emits a `CertificateRedeemed` event.
     */
    function redeemCondensedCertificate(bytes calldata _signature, uint256 _combinedValue, bytes32[] calldata _certificateIDs)
    external
        returns (bool)
    {
        bytes32 certIDsCondensed = _condenseCertificateIDs(_certificateIDs);
        bytes32 condenserHash = _getCondensedCertificateHash(certIDsCondensed, _combinedValue, msg.sender);
        address signer = condenserHash.toEthSignedMessageHash().recover(_signature);
        require(condenserDelegates[signer], "Not valid condenser delegate");

        for (uint8 i = 0; i < _certificateIDs.length; i++) {
            require(!certificateTypes[_certificateIDs[i]].claimed[msg.sender], "Cert already claimed");
            certificateTypes[_certificateIDs[i]].claimed[msg.sender] = true;
        }

        _mint(msg.sender, _combinedValue);
        emit CondensedCertificateRedeemed(msg.sender, _combinedValue, _certificateIDs);
        return true;
    }



    // View Functions

    /**
     * @dev Returns the metadata string for a `_certificateID`
     */
    function getCertificateData(bytes32 _certificateID) external view returns (string memory) {
        return certificateTypes[_certificateID].metadata;
    }
    
    /**
     * @dev Returns the amount for a `_certificateID`
     */
    function getCertificateAmount(bytes32 _certificateID) external view returns (uint256) {
        return certificateTypes[_certificateID].amount;
    }

    /**
     * @dev Calls internal function to return the ID for a certificate from parameters used to create certificate
     */
    function getCertificateID(uint _amount, address[] calldata _delegates, string calldata _metadata) external view returns (bytes32) {
        return _getCertificateID(_amount,_delegates, _metadata);
    }

    /**
     * @dev Calls internal function to return the hash to sign for a certificate to redeemer
     */
    function getCertificateHash(bytes32 _certificateID, address _redeemer) external view returns (bytes32) {
        return _getCertificateHash(_certificateID, _redeemer);
    }

    /**
     * @dev Calls internal function
     */
    function getCondensedCertificateHash(bytes32 _condensedIDHash, uint256 _amount, address _redeemer) external view returns (bytes32) {
        return _getCondensedCertificateHash(_condensedIDHash, _amount, _redeemer);
    }

    /**
     * @dev Calls internal function to return boolean of whether a message and signature matches a certificate
     */
    function isDelegateSigned(bytes32 _messageHash, bytes calldata _signature, bytes32 _certificateID) external view returns (bool) {
        return _isDelegateSigned(_messageHash, _signature, _certificateID);
    }

    /**
     * @dev Returns boolean of whether a `_delegate` address is a valid delagate of a certificate
     */
    function isCertificateDelegate(bytes32 _certificateID, address _delegate) external view returns (bool) {
        return certificateTypes[_certificateID].delegates[_delegate];
    }

    /**
     * @dev Returns boolean of whether a certificate has been claimed by a `_recipient` address
     */
    function isCertificateClaimed(bytes32 _certificateID, address _recipient) external view returns (bool) {
        return certificateTypes[_certificateID].claimed[_recipient];
    }

    function condenseCertificateIDs(bytes32[] calldata _ids) external pure returns (bytes32) {
        return _condenseCertificateIDs(_ids);
    }

    // Internal Functions

    /** @dev Packs an `_amount`, this contract's address, `_delegates` array, and string `_metadata`
     * and performs a keccak256 on the packed bytes and returns the bytes32 result
     */
    function _getCertificateID(uint256 _amount, address[] memory _delegates, string memory _metadata) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(_amount,address(this),_delegates, _metadata));
    }

    /** @dev something
     */
    function _getCondensedCertificateHash(bytes32 _condensedHash, uint256 _amount, address _redeemer) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(_condensedHash, _amount, _redeemer, address(this)));
    }

    /** @dev something
     */
    function _condenseCertificateIDs(bytes32[] memory _ids) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_ids));
    }

    /** @dev Checks a `_signature` with a `_messageHash` to verify if the signer is a delegate for a given `_certificateID`
     * and performs a keccak256 on the packed bytes and returns the bytes32 result
     */
    function _isDelegateSigned(bytes32 _messageHash, bytes memory _signature, bytes32 _certificateID) internal view returns (bool) {
        return certificateTypes[_certificateID].delegates[_messageHash.toEthSignedMessageHash().recover(_signature)];
    }

    function _getCertificateHash(bytes32 _certificateID, address _redeemer) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(_certificateID, address(this), _redeemer));
    }


    /**
     * @dev Emitted when a new certificate is created for an `amount` that can have
     * any of the `delegates` for signing certificates
     */
    event CertificateTypeCreated(bytes32 indexed id, uint256 amount, address[] delegates);

    /**
     * @dev Emitted when a `caller` successfully redeems a certificate and receives `value` of tokens
     */
    event CertificateRedeemed(address indexed caller, uint256 value, bytes32 certificateID);

    /**
     * @dev Emitted when a `caller` successfully redeems a certificate and receives `value` of tokens
     */
    event CondensedCertificateRedeemed(address indexed caller, uint256 value, bytes32[] certificateIDs);
}
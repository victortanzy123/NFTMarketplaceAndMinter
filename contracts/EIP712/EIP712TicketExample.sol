//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

contract EIP712TicketExample is EIP712 {
  /// @dev For this contract it should always be keccak256("Ticket(string eventName,uint256 price,address signedBy)")
  /// @dev but we are assigning the value in the constructor for the sake of learning
  bytes32 immutable typedDataHash;

  constructor(
    string memory domainName_,
    string memory signatureVersion_,
    bytes32 typedDataHash_
  ) EIP712(domainName_, signatureVersion_) {
    typedDataHash = typedDataHash_;
  }

  /// @notice Represents an off-chain ticket for an event
  struct Ticket {
    string eventName; // The name of the event
    uint256 price; // The price (in wei) of the event
  }

  /// Returns the address of the signer of that the ticket
  /// @param eventName The name of the event
  /// @param price  The price (in wei) of the event
  /// @param signature The ticket seller signature
  function getSigner(
    string calldata eventName,
    uint256 price,
    bytes memory signature
  ) public view returns (address signer) {
    Ticket memory ticket = Ticket(eventName, price);

    signer = _verify(ticket, signature);
  }

  /// @notice Verifies the signature for a given Ticket, returning the address of the signer.
  /// @dev Will revert if the signature is invalid.
  /// @param ticket A ticket describing an event
  /// @param signature The ticket seller signature
  function _verify(Ticket memory ticket, bytes memory signature)
    internal
    view
    returns (address decodedSigner)
  {
    bytes32 digest = _hashTypedData(ticket);

    decodedSigner = ECDSA.recover(digest, signature);
  }

  /// @notice Returns a hash of a given Ticket, prepared using EIP712 typed data hashing rules. (HASH STRUCT - {typedHash, ...parameters})
  /// @param ticket A ticket describing an event
  function _hashTypedData(Ticket memory ticket) internal view returns (bytes32 hashTypedData) {
    return
      _hashTypedDataV4(
        keccak256(
          abi.encode(
            typedDataHash, // keccak hash of typed data struct
            keccak256(bytes(ticket.eventName)), // Pack into bytes32 size for string - encode string to get hash
            ticket.price // uint256 value
          )
        )
      );
  }
}

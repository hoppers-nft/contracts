// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

/// @title IERC2981Royalties
/// @dev Interface for the ERC2981 - Token Royalty standard
interface IERC2981Royalties {
    /// @notice Called with the sale price to determine how much royalty
    //          is owed and to whom.
    /// @param _tokenId - the NFT asset queried for royalty information
    /// @param _value - the sale price of the NFT asset specified by _tokenId
    /// @return _receiver - address of who should be sent the royalty payment
    /// @return _royaltyAmount - the royalty payment amount for value sale price
    function royaltyInfo(uint256 _tokenId, uint256 _value)
        external
        view
        returns (address _receiver, uint256 _royaltyAmount);
}

abstract contract ERC2981 is IERC2981Royalties {
    address public ROYALTY_ADDRESS;
    uint256 public ROYALTY_FEE; // 0 - 100 %

    event ChangeRoyalty(address newAddress, uint256 newFee);

    constructor(address _ROYALTY_ADDRESS, uint256 _ROYALTY_FEE) {
        ROYALTY_ADDRESS = _ROYALTY_ADDRESS;
        ROYALTY_FEE = _ROYALTY_FEE;
    }

    function supportsInterface(bytes4 interfaceId)
        external
        view
        virtual
        returns (bool)
    {
        return
            interfaceId == type(IERC2981Royalties).interfaceId ||
            interfaceId == 0x01ffc9a7; //erc165
    }

    function royaltyInfo(
        uint256 _tokenId, // solhint-disable-line
        uint256 _value
    ) external view returns (address _receiver, uint256 _royaltyAmount) {
        return (ROYALTY_ADDRESS, (_value * ROYALTY_FEE) / 100);
    }
}

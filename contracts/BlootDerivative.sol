// SPDX-License-Identifier: MIT
pragma solidity ^0.6.5;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BlootDerivative is ERC721Upgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter internal toyTokenIDs;
    CountersUpgradeable.Counter internal paintingTokenIDs;
    CountersUpgradeable.Counter internal statuetteTokenIDs;

    uint256 internal toyTokenIDBase;
    uint256 internal paintingTokenIDBase;
    uint256 internal statuetteTokenIDBase;

    address public _owner;
    bool public isOpenPayment;

    bool public isPausedClaimingToy;
    bool public isPausedClaimingPainting;
    bool public isPausedClaimingStatteute;

    mapping(address => uint256) internal addressToClaimedToy;
    mapping(address => uint256) internal addressToClaimedPainting;
    mapping(address => uint256) internal addressToClaimedStateutte;

    mapping(uint256 => bool) public oldTokenIDUsed;

    mapping(address => uint256) internal addressToMigratedCameo;
    mapping(address => uint256) internal addressToMigratedHonorary;
    
    mapping(address => uint256) internal addressToRoyalty;
    ERC721 blootNFT;

    struct Point {
        uint256 x;
        uint256 y;
    }

    struct Rectangle {
        Point leftBottom;
        Point rightTop;
    }

    struct LandMetadata {
        uint256 collectionID;
        uint256 tokenID;
    }

    struct LandDerivateMetadata {
        address collectionAddress;
        uint256 tokenID;
    }

    string _contractURI;
    bool allowMetadataForAllReserved;
    uint256 landWidth;
    uint256 landHeight;
    uint256 totalCollection;
    uint256 constant landTokenBase = 10000;
    address constant blootAddress = 0xCAccb157236B0969fe21eb486f2Bc5dc0662a5c5;
    address constant metaKeyAddress = 0xbA8886bf3a6f0740e622AF240c54c9A6439DE0bE;
    mapping(address => mapping(uint256 => uint256)) claimedLandOf;
    mapping(uint256 => LandMetadata) public landRoyalMetadataOf;
    mapping(uint256 => LandDerivateMetadata[]) public landDerivativeMetadataOf;
    mapping(uint256 => uint256) public landDerivativeBalance;
    mapping(uint256 => address) collectionAddressByIndex;
    mapping(address => uint256[]) public collectionIndicesByAddress;
    mapping(uint256 => Rectangle) internal collectionRectByIndex;

    mapping(address => uint256) honoraries;
    mapping(address => uint256) mekakeyWallets;

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner" );
        _;
    }

    function initialize() initializer external {
        __ERC721_init("MyPFPland", "MyPFPland");
        _owner = msg.sender;

        toyTokenIDBase = 0;
        paintingTokenIDBase = 300;
        statuetteTokenIDBase = 400;
        blootNFT = ERC721(blootAddress);
        landWidth = 100;
        landHeight = 100;
        totalCollection = 0;
    }

    function claim(uint256 _category, uint256 _count) external payable {
        require(_category >= 1, "out of range");
        require(_category <= 3, "out of range");
        if (_category == 1)
            require(isPausedClaimingToy == false, "toy claiming is paused");
        if (_category == 2)
            require(isPausedClaimingPainting == false, "painting claiming is paused");
        if (_category == 3)
            require(isPausedClaimingStatteute == false, "statteute claiming is paused");
        
        uint256 totalDerivative = getTotalDerivative(msg.sender, _category);
        if (_category == 1)
            totalDerivative += addressToMigratedCameo[msg.sender];
        else if (_category == 2)
            totalDerivative += addressToMigratedHonorary[msg.sender];

        uint256 tokenID = 0;
        if (_category == 1)
            require(totalDerivative >= addressToClaimedToy[msg.sender] + _count, "already claimed all toys");
        else if (_category == 2)
            require(totalDerivative >= addressToClaimedPainting[msg.sender] + _count, "already claimed all paintings");
        else if (_category == 3)
            require(totalDerivative >= _count, "already claimed all statteutes");
    
        for (uint8 i = 0; i < _count; i++) {
            if (_category == 1) {
                toyTokenIDs.increment();
                tokenID = toyTokenIDs.current() + toyTokenIDBase;
            } else if (_category == 2) {
                paintingTokenIDs.increment();
                tokenID = paintingTokenIDs.current() + paintingTokenIDBase;
            } else if (_category == 3) {
                statuetteTokenIDs.increment();
                tokenID = statuetteTokenIDs.current() + statuetteTokenIDBase;
            }
            _safeMint(msg.sender, tokenID);
            _setTokenURI(tokenID, uint2str(tokenID));
        }

        if (_category == 1)
            addressToClaimedToy[msg.sender] += _count;
        else if (_category == 2)
            addressToClaimedPainting[msg.sender] += _count;

        // set oldTokenIDUsed true for those IDs already used
        if (totalDerivative > 0 && _category == 3) {
            for (uint8 i = 0; i < blootNFT.balanceOf(msg.sender); i++) {
                uint256 tokenId = blootNFT.tokenOfOwnerByIndex(msg.sender, i);
                if (tokenId <= 1484) {
                    oldTokenIDUsed[tokenId] = true;
                }
            }
        }
    }

    function airdrop(address[] calldata _claimList, uint256[] calldata _tokenIDs, uint256 _count) external onlyOwner {
        for (uint256 i = 0; i < _count; i++) {
            uint256 tokenID = 0;
            if (_tokenIDs[i] <= 300) {
                toyTokenIDs.increment();
                tokenID = toyTokenIDs.current() + toyTokenIDBase;

                addressToClaimedToy[_claimList[i]] += 1;
            } else if (_tokenIDs[i] <= 400) {
                paintingTokenIDs.increment();
                tokenID = paintingTokenIDs.current() + paintingTokenIDBase;

                addressToClaimedPainting[_claimList[i]] += 1;
            } else {
                statuetteTokenIDs.increment();
                tokenID = statuetteTokenIDs.current() + statuetteTokenIDBase;
            }
            _safeMint(_claimList[i], tokenID);
            _setTokenURI(tokenID, uint2str(tokenID));
            if (tokenID > 400) {
                for (uint256 j = 0; j < blootNFT.balanceOf(_claimList[i]); j++) {
                    uint256 tokenId = blootNFT.tokenOfOwnerByIndex(_claimList[i], j);
                    if (tokenId <= 1484)
                        oldTokenIDUsed[tokenId] = true;
                }
            }
        }
    }

    function getDerivativesToClaim(address _claimer, uint256 _category) external view returns(uint256) {
        uint256 remain = 0;
        if (_category < 1 || _category > 3)
            return remain;
        
        uint256 totalDerivative = getTotalDerivative(_claimer, _category);
        if (_category == 1) {
            totalDerivative += addressToMigratedCameo[_claimer];
            remain = totalDerivative - addressToClaimedToy[_claimer];
        }
        else if (_category == 2) {
            totalDerivative += addressToMigratedHonorary[_claimer];
            remain = totalDerivative - addressToClaimedPainting[_claimer];
        }
        else if (_category == 3) {
            remain = totalDerivative;
        }

        return remain;
    }

    function getTotalDerivative(address _claimer, uint256 _category) internal view returns(uint256) {
        uint256 result = 0;
        if (blootNFT.balanceOf(_claimer) == 0)
            return result;
        uint256 tokenIdMin;
        uint256 tokenIdMax;
        if (_category == 1) {
            tokenIdMin = 4790;
            tokenIdMax = 4962;
        } else if (_category == 2) {
            tokenIdMin = 4963;
            tokenIdMax = 5000;
        } else if (_category == 3) {
            tokenIdMin = 1;
            tokenIdMax = 1484;
        }

        for (uint256 i = 0; i < blootNFT.balanceOf(_claimer); i++) {
            uint256 tokenId = blootNFT.tokenOfOwnerByIndex(_claimer, i);
            if (tokenId >= tokenIdMin && tokenId <= tokenIdMax) {
                if (_category == 3) {
                    if (!oldTokenIDUsed[tokenId])
                        result++;
                }
                else
                    result++;
            }
        }

        return result;
    }

    function setPauseClaimingToy(bool _pauseClaimingToy) external onlyOwner {
        isPausedClaimingToy = _pauseClaimingToy;
    }

    function setPauseClaimingPainting(bool _pauseClaimingPainting) external onlyOwner {
        isPausedClaimingPainting = _pauseClaimingPainting;
    }

    function setPauseClaimingStatteute(bool _pauseClaimingStatteute) external onlyOwner {
        isPausedClaimingStatteute = _pauseClaimingStatteute;
    }

    function setBatchCameoWhitelist(address[] calldata _whitelist, uint256 _count) external onlyOwner {
        for (uint256 i = 0; i < _count; i++) {
            addressToMigratedCameo[_whitelist[i]] += 1;
        }
    }

    function setBatchHonoraryWhitelist(address[] calldata _whitelist, uint256 _count) external onlyOwner {
        for (uint256 i = 0; i < _count; i++) {
            addressToMigratedHonorary[_whitelist[i]] += 1;
        }
    }

    function setBatchCameoBlacklist(address[] calldata _blacklist, uint256 _count) external onlyOwner {
        for (uint256 i = 0; i < _count; i++) {
            addressToMigratedCameo[_blacklist[i]] = 0;
        }
    }

    function setBatchHonoraryBlacklist(address[] calldata _blacklist, uint256 _count) external onlyOwner {
        for (uint256 i = 0; i < _count; i++) {
            addressToMigratedHonorary[_blacklist[i]] = 0;
        }
    }

    // additional honoraries, will be supplimentary for addressToMigratedHonorary
    function setBatchHonoraries(address[] calldata _whitelist, uint256 _count) external onlyOwner {
        for (uint256 i = 0; i < _count; i++) {
            honoraries[_whitelist[i]] += 1;
        }
    }

    function setBatchMekakeyWallets(address[] calldata _whitelist, uint256 _count) external onlyOwner {
        for (uint256 i = 0; i < _count; i++) {
            mekakeyWallets[_whitelist[i]] += 1;
        }
    }

    function clearBatchHonoraries(address[] calldata _blacklist, uint256 _count) external onlyOwner {
        for (uint256 i = 0; i < _count; i++) {
            honoraries[_blacklist[i]] = 0;
        }
    }

    function clearBatchMekakeyWallets(address[] calldata _blacklist, uint256 _count) external onlyOwner {
        for (uint256 i = 0; i < _count; i++) {
            mekakeyWallets[_blacklist[i]] = 0;
        }
    }

    function setBaseURI(string calldata _baseURI) external onlyOwner {
        super._setBaseURI(_baseURI);
    }

    function setTokenURI(uint256 _tokenID, uint256 _tokenURI) external onlyOwner {
        super._setTokenURI(_tokenID, uint2str(_tokenURI));
    }

    function setTokenURIs(uint256[] calldata _tokenIDs, uint256[] calldata _tokenURIs, uint256 _count) external onlyOwner {
        for (uint256 i = 0; i < _count; i++) {
            super._setTokenURI(_tokenIDs[i], uint2str(_tokenURIs[i]));
        }
    }

    function openPayment(bool _open) external onlyOwner {
        isOpenPayment = _open;
    }

    function setBatchRoyalty(address[] calldata _people, uint256[] calldata _amount, uint256 _count) external onlyOwner {
        for (uint256 i = 0; i < _count; i++) {
            addressToRoyalty[_people[i]] = _amount[i];
        }
    }

    function setRoyalty(address _person, uint256 _amount) external onlyOwner {
        addressToRoyalty[_person] = _amount;
    }

    function royaltyOf(address _person) external view returns(uint256) {
        return addressToRoyalty[_person];
    }

    function withdraw() external onlyOwner {
        (bool success, ) = _owner.call{value: address(this).balance}("");
        require(success, "Failed to send");
    }

    function withdrawRoyalty() external {
        require(isOpenPayment == true, "Payment is closed");
        require(addressToRoyalty[msg.sender] > 0, "You don't have any royalties");
        require(address(this).balance >= addressToRoyalty[msg.sender], "Insufficient balance in the contract");
        require(msg.sender != address(0x0), "invalid caller");

        (bool success, ) = msg.sender.call{value: addressToRoyalty[msg.sender]}("");
        require(success, "Failed to send eth");
        addressToRoyalty[msg.sender] = 0;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _owner = newOwner;
    }

    function claimLand(uint256 x, uint256 y, uint256 collectionID) external payable {
        require(x <= landWidth && y <= landHeight, "exceeds boundary");
        require(x > collectionRectByIndex[collectionID].leftBottom.x && y > collectionRectByIndex[collectionID].leftBottom.y && x <= collectionRectByIndex[collectionID].rightTop.x && y <= collectionRectByIndex[collectionID].rightTop.y, "not contained");

        address collectionAddress = collectionAddressByIndex[collectionID];
        uint256 claimable;
        if (collectionAddress == metaKeyAddress) {
            claimable = mekakeyWallets[msg.sender];
        } else if (collectionAddress == blootAddress) {
            if (collectionID == 0 || collectionID == 1 || collectionID == 2 || collectionID == 3) { // honorary collection ids
                claimable = addressToMigratedHonorary[msg.sender] + honoraries[msg.sender];
            } else {
                require(msg.value == 30000000000000000, "invalid amount"); //0.03 ETH
                ERC721 collection = ERC721(collectionAddress);
                claimable = collection.balanceOf(msg.sender);
                claimable -= (addressToMigratedHonorary[msg.sender] + honoraries[msg.sender]);
            }
        } else {
            require(msg.value == 30000000000000000, "invalid amount"); //0.03 ETH
            ERC721 collection = ERC721(collectionAddress);
            claimable = collection.balanceOf(msg.sender);
        }
        
        require(claimable > 0, "Don't own any NFT in this collection");
        require(claimedLandOf[msg.sender][collectionID] < claimable, "Already claimed all lands");
        uint256 assetID = _encodeTokenId(x, y);
        _safeMint(msg.sender, landTokenBase + assetID);
        _setTokenURI(landTokenBase + assetID, uint2str(landTokenBase + assetID));
        if (collectionID == 0 || collectionID == 1 || collectionID == 2 || collectionID == 3) { // handle honorary exception
            for (uint256 i = 0; i < 4; i++) {
                claimedLandOf[msg.sender][i] ++;
            }
        } else {
            uint256[] memory collectionIndices = collectionIndicesByAddress[collectionAddress];
            for (uint256 i = 0; i < collectionIndices.length; i++) {
                claimedLandOf[msg.sender][collectionIndices[i]] ++;
            }
        }
    }

    function landOwnerOf(uint256 tokenId) external view returns (address) {
        ERC721 collection = ERC721(address(this));
        try collection.ownerOf(tokenId) returns(address owner) {
            return owner;
        } catch Error(string memory /*reason*/) {
            return address(0x0);
        }
    }

    function _transfer(address /* from */, address /* to */, uint256 tokenId) internal override {
        if (tokenId > landTokenBase) {
            // remove its royal and derivative tokens
            LandMetadata memory royalMetadata;
            royalMetadata.collectionID = 0;
            royalMetadata.tokenID = 0;
            landRoyalMetadataOf[tokenId] = royalMetadata;
            delete landDerivativeMetadataOf[tokenId];
        }
    }

    function updateLandRoyalMetaData(uint256 x, uint256 y, uint256 collectionIDOfRoyalMetadata, uint256 tokenID) external {
        require(x <= landWidth && y <= landHeight, "exceeds boundary");
        uint256 assetID = _encodeTokenId(x, y);
        require(super.ownerOf(landTokenBase + assetID) == msg.sender, "You are not the owner of this land");
        if (!allowMetadataForAllReserved) {
            require(x > collectionRectByIndex[collectionIDOfRoyalMetadata].leftBottom.x && y > collectionRectByIndex[collectionIDOfRoyalMetadata].leftBottom.y && x <= collectionRectByIndex[collectionIDOfRoyalMetadata].rightTop.x && y <= collectionRectByIndex[collectionIDOfRoyalMetadata].rightTop.y, "not contained");
        }
        address collectionAddress = collectionAddressByIndex[collectionIDOfRoyalMetadata];
        ERC721 collection = ERC721(collectionAddress);
        require(collection.ownerOf(tokenID) == msg.sender, "You are not the owner of this tokenID");
        LandMetadata memory royalMetadata;
        royalMetadata.collectionID = collectionIDOfRoyalMetadata;
        royalMetadata.tokenID = tokenID;
        landRoyalMetadataOf[landTokenBase + assetID] = royalMetadata;
        delete landDerivativeMetadataOf[landTokenBase + assetID];
    }

    function updateLandDerivativeMetaData(uint256 x, uint256 y, address collectionAddrsOfDerMetadata, uint256 tokenID) external {
        require(x <= landWidth && y <= landHeight, "exceeds boundary");
        uint256 assetID = _encodeTokenId(x, y);
        require(super.ownerOf(landTokenBase + assetID) == msg.sender, "You are not the owner of this land");
        require((landRoyalMetadataOf[landTokenBase + assetID].collectionID != 0 || landRoyalMetadataOf[landTokenBase + assetID].tokenID != 0), "Need to set royal NFT first");
        ERC721 collection = ERC721(collectionAddrsOfDerMetadata);
        require(collection.ownerOf(tokenID) == msg.sender, "You are not the owner of this tokenID");
        LandDerivateMetadata memory derivativeMetadata;
        derivativeMetadata.collectionAddress = collectionAddrsOfDerMetadata;
        derivativeMetadata.tokenID = tokenID;
        landDerivativeMetadataOf[landTokenBase + assetID].push(derivativeMetadata);
        landDerivativeBalance[landTokenBase + assetID] ++;
    }

    function setAllowMetadataForAllReserved(bool _allowMetadataForAllReserved) external onlyOwner {
        allowMetadataForAllReserved = _allowMetadataForAllReserved;
    }

    function getLandMetaData(uint256 collectionID, uint256 tokenID) external view returns(string memory) {
        address collectionAddress = collectionAddressByIndex[collectionID];
        ERC721 collection = ERC721(collectionAddress);
        try collection.tokenURI(tokenID) returns(string memory tokenURI) {
            return tokenURI;
        } catch Error(string memory /*reason*/) {
            return "";
        }
    }

    function collectionIDAt(uint256 x, uint256 y) external view returns (uint256) {
        uint256 collectionID;
        if (x > landWidth || y > landHeight) {
            collectionID = 100000;
            return collectionID;
        }
        Rectangle memory area;
        Point memory pt;
        pt.x = x;
        pt.y = y;
        for (uint256 i = 0; i < totalCollection; i++) {
            area = collectionRectByIndex[i];
            if (isInsideCollectionRect(pt, area)) {
                collectionID = i;
                return collectionID;
            }
        }
        collectionID = 100000;
        return collectionID;
    }

    function totalRoyalBalanceOf(address owner, uint256 collectionID) external view returns (uint256) {
        if (!allowMetadataForAllReserved) {
            address collectionAddress = collectionAddressByIndex[collectionID];
            ERC721 collection = ERC721(collectionAddress);
            return collection.balanceOf(owner);
        } else {
            uint256 totalBalance = 0;
            address lastAddress;
            for (uint256 i = 0; i < totalCollection; i++) {
                address collectionAddress = collectionAddressByIndex[i];
                if (collectionAddress == lastAddress)
                    continue;
                lastAddress = collectionAddress;
                ERC721 collection = ERC721(collectionAddress);
                totalBalance += collection.balanceOf(owner);
            }
            return totalBalance;
        }
    }

    function royalTokenOfOwnerByIndex(address owner, uint256 index, uint256 collectionID) external view returns (uint256, uint256) {
        uint256 tokenID;
        if (!allowMetadataForAllReserved) {
            address collectionAddress = collectionAddressByIndex[collectionID];
            ERC721 collection = ERC721(collectionAddress);
            tokenID = collection.tokenOfOwnerByIndex(owner, index);
            return (collectionID, tokenID);
        } else {
            uint256 totalBalance = 0;
            address lastAddress;
            for (uint256 i = 0; i < totalCollection; i++) {
                address collectionAddress = collectionAddressByIndex[i];
                if (collectionAddress == lastAddress)
                    continue;
                lastAddress = collectionAddress;
                ERC721 collection = ERC721(collectionAddress);
                totalBalance += collection.balanceOf(owner);
                if (totalBalance - 1 < index)
                    continue;
                uint256 tokenIndex = index - (totalBalance - collection.balanceOf(owner));
                tokenID = collection.tokenOfOwnerByIndex(owner, tokenIndex);
                return (i, tokenID);
            }
        }
    }

    function isInsideCollectionRect(Point memory point, Rectangle memory area) public pure returns(bool) {
        if (point.x > area.leftBottom.x && point.y > area.leftBottom.y && point.x <= area.rightTop.x && point.y <= area.rightTop.y)
            return true;
        else
            return false;
    }

    function setCollectionRect(uint256 leftBottomX, uint256 leftBottomY, uint256 rightTopX, uint256 rightTopY, address collectionAddress) public onlyOwner {
        Rectangle memory area;
        area.leftBottom.x = leftBottomX;
        area.leftBottom.y = leftBottomY;

        area.rightTop.x = rightTopX;
        area.rightTop.y = rightTopY;
        collectionRectByIndex[totalCollection] = area;
        collectionAddressByIndex[totalCollection] = collectionAddress;
        if (totalCollection != 0 && totalCollection != 1 && totalCollection != 2 && totalCollection != 3)
            collectionIndicesByAddress[collectionAddress].push(totalCollection);
        totalCollection ++;
    }

    function setBatchCollectionRect(uint256[] calldata leftBottomX, uint256[] calldata leftBottomY, uint256[] calldata rightTopX, uint256[] calldata rightTopY, address[] calldata collectionAddress, uint256 count) external onlyOwner {
        Rectangle memory area;
        for (uint256 i = 0; i < count; i++) {
            area.leftBottom.x = leftBottomX[i];
            area.leftBottom.y = leftBottomY[i];

            area.rightTop.x = rightTopX[i];
            area.rightTop.y = rightTopY[i];
            collectionRectByIndex[totalCollection] = area;
            collectionAddressByIndex[totalCollection] = collectionAddress[i];
            collectionIndicesByAddress[collectionAddress[i]].push(totalCollection);
            totalCollection ++;
        }
    }

    function _encodeTokenId(uint256 x, uint256 y) public view returns (uint256) {
        return (x - 1) * landHeight + y;
    }

    function _decodeTokenId(uint256 value) external view returns (uint256 x, uint256 y) {
        x = value / landHeight + 1;
        if (value % landHeight == 0)
            x = x - 1;        
        y = value - (x - 1) * landHeight;
    }

    // for opensea collection 
    function setContractURI(string calldata _contractURI_) external onlyOwner() {
        _contractURI = _contractURI_;
    }

    // for opensea collection 
    function contractURI() external view returns (string memory) {
        return _contractURI;
    }

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
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
}

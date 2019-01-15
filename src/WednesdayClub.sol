pragma solidity ^0.4.25;

import "./ownable.sol";
import "./pausable.sol";
import "./destructible.sol";
import "./tokenInterfaces.sol";

contract WednesdayClub is Ownable, Destructible, Pausable {

    // The structure of a post
    struct Post {
        uint256 id;
        address poster;
        uint256 value;
        uint256 likes;
        string content;
        uint256 timestamp;
        string media;
        uint256 reportCount;
    }

    //onlyWednesdays Modifier
    modifier onlyWednesdays() {
        //require true only for testing
        //require(true);
        uint8 dayOfWeek = uint8((now / 86400 + 4) % 7);
        require(dayOfWeek == 3);
        _;
    }

    // The posts that each address has written
    mapping(address => Post[]) public userPosts;

    // All the posts ever written by ID
    mapping(uint256 => Post) public posts;

    // Keep track of all IDs - use for loading
    uint256[] public postIds;

    // followers: list of who is following
    mapping(address => address[]) public followers;

    // following: list of who you are following
    mapping(address => address[]) public following;


    // WednesdayCoin contract being held
    WednesdayCoin public wednesdayCoin;

    // amountForPost
    uint256 public amountForPost;

    // minimum amount For likes
    uint256 public minimumForLike;

    // minimum amount For following
    uint256 public minimumForFollow;

    // minimum amount For reporting
    uint256 public minimumForReporting;

    //ensure that each user can only post once at everyinterval
    mapping(address => uint) public postTime;

    //interval user has to wait to be able to post
    uint public postInterval;

    //ensure that each user can only post once at everyinterval
    mapping(address => uint) public reportTime;

    //interval user has to wait to be able to post
    uint public reportInterval;

    //constructor
    constructor() public {
        //for testing -- 0xedfc38fed24f14aca994c47af95a14a46fbbaa16
        wednesdayCoin = WednesdayCoin(0x7848ae8f19671dc05966dafbefbbbb0308bdfabd);
        amountForPost = 10000000000000000000000;
        postInterval = 10 minutes;
        minimumForLike = 1000000000000000000000;
        minimumForFollow = 100000000000000000000;
        minimumForReporting = 100000000000000000000;
        reportInterval = 10 minutes;
    }

    function receiveApproval(address from, uint256 value, address tokenContract, bytes extraData) public returns (bool) {

    }

    // Adds a new post
    function writePost(uint256 _id, uint256 _value, string memory _content, string memory _media) public onlyWednesdays whenNotPaused {
        require(amountForPost == _value);
        require(hasElapsed());
        require(bytes(_content).length > 0 || bytes(_media).length > 0);
        _id = uint256(keccak256(_id, now, blockhash(block.number - 1), block.coinbase));
        //for create
        if (wednesdayCoin.transferFrom(msg.sender, this, _value)) {
            Post memory post = Post(_id, msg.sender, 0, 0, _content, now, _media, 0);
            userPosts[msg.sender].push(post);
            posts[_id] = post;
            postIds.push(_id);
            postTime[msg.sender] = now;
        } else {
            revert();
        }
    }

    function likePost(uint256 _id, uint256 _value) public onlyWednesdays whenNotPaused {
        require(_value >= minimumForLike);
        address poster;
        //ensure that post exists
        if (posts[_id].id == _id) {
            //shouldnt be able to like your own post
            require(posts[_id].poster != msg.sender);
            if (wednesdayCoin.transferFrom(msg.sender, posts[_id].poster, _value)) {
                posts[_id].value += _value;
                posts[_id].likes++;
                poster = posts[_id].poster;
                // updating entry from userPosts
                for (uint i = 0; i < userPosts[poster].length; i++) {
                    if (userPosts[poster][i].id == _id) {
                        userPosts[poster][i].value += _value;
                        userPosts[poster][i].likes++;
                    }
                }
            } else {
                revert();
            }
        }
    }

    function reportPost(uint256 _id, uint256 _value) public onlyWednesdays whenNotPaused {
        require(hasElapsedReport());
        address poster;
        //ensure that post exists
        if (posts[_id].id == _id) {
            //shouldnt be able to like your own post
            require(posts[_id].poster != msg.sender);
            if (wednesdayCoin.transferFrom(msg.sender, this, _value)) {
                posts[_id].reportCount++;
                poster = posts[_id].poster;
                // updating entry from userPosts
                for (uint i = 0; i < userPosts[poster].length; i++) {
                    if (userPosts[poster][i].id == _id) {
                        userPosts[poster][i].reportCount++;
                    }
                }
                reportTime[msg.sender] = now;
            } else {
                revert();
            }
        }
    }

    //delete a user post
    function deleteUserPost(address _user, uint256 _id) public onlyOwner {
        for(uint i = 0; i < userPosts[_user].length; i++) {
            if(userPosts[_user][i].id == _id){
                delete userPosts[_user][i];
            }
        }
        deleteIdFromPostIds(_id);
    }

    //delete a public post
    function deletePublicPost(uint256 _id) public onlyOwner {
        if(posts[_id].id == _id){
            delete posts[_id];
        }
        deleteIdFromPostIds(_id);
    }

    function deleteAllPosts() public onlyOwner {
        for(uint i = 0; i < postIds.length; i++) {
            address poster = posts[i].poster;
            delete userPosts[poster][i];
            delete posts[i];
        }
        delete postIds;
    }

    function deleteIdFromPostIds(uint256 _id) public onlyOwner  {
        uint256 indexToDelete;
        for(uint i = 0; i < postIds.length; i++) {
            if(postIds[i] == _id) {
                indexToDelete = i;
            }
        }
        delete postIds[indexToDelete];
    }

    //to make it easier this one calls both deletes
    function deletePost(address _user, uint256 _id) public onlyOwner {
        deleteUserPost(_user, _id);
        deletePublicPost(_id);
    }

    function follow(address _address, uint256 _value) public onlyWednesdays whenNotPaused {
        require(_value >= minimumForFollow);
        require(msg.sender != _address);
        // update that user is following address
        if (wednesdayCoin.transferFrom(msg.sender, _address, _value)) {
            following[msg.sender].push(_address);
            // update address followers
            followers[_address].push(msg.sender);
        } else {
            revert();
        }
    }

    function unfollow(address _address) public onlyWednesdays whenNotPaused {
        require(msg.sender != _address);
        // delete that user is folowing address
        for(uint i = 0; i < following[msg.sender].length; i++) {
            if(following[msg.sender][i] == _address){
                delete following[msg.sender][i];
            }
        }
        // delete address followers
        for(i = 0; i < followers[_address].length; i++) {
            if(followers[_address][i] == msg.sender){
                delete followers[_address][i];
            }
        }
    }

    function setAmountForPost(uint256 _amountForPost) public onlyOwner {
        amountForPost = _amountForPost;
    }

    function getUserPostLength(address _user) public view returns (uint256){
        return userPosts[_user].length;
    }

    // Used for transferring any accidentally sent ERC20 Token by the owner only
    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }

    // Used for transferring any accidentally sent Ether by the owner only
    function transferEther(address dest, uint amount) public onlyOwner {
        dest.transfer(amount);
    }

    function hasElapsed() public returns (bool) {
        if (now >= postTime[msg.sender] + postInterval) {
            //has elapsed from postTime[msg.sender]
            return true;
        }
        return false;
    }

    function hasElapsedReport() public returns (bool) {
        if (now >= reportTime[msg.sender] + reportInterval) {
            //has elapsed from reportTime[msg.sender]
            return true;
        }
        return false;
    }

    function setPostInterval(uint _postInterval) public onlyOwner {
        postInterval = _postInterval;
    }

    function setReportingInterval(uint _reportInterval) public onlyOwner {
        reportInterval = _reportInterval;
    }
    function setMinimumForLike(uint _minimumForLike) public onlyOwner {
        minimumForLike = _minimumForLike;
    }

    function setMinimumForFollow(uint _minimumForFollow) public onlyOwner {
        minimumForFollow = _minimumForFollow;
    }

    function setMinimumForReporting(uint _minimumForReporting) public onlyOwner {
        minimumForReporting = _minimumForReporting;
    }

    function getPostIdsLength() public view returns (uint256){
        return postIds.length;
    }

    function getFollowersLength(address _address) public view returns (uint256){
        return followers[_address].length;
    }

    function getFollowingLength(address _address) public view returns (uint256){
        return following[_address].length;
    }
}
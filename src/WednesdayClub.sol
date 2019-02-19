pragma solidity ^0.4.25;

import "./ownable.sol";
import "./pausable.sol";
import "./destructible.sol";
import "./tokenInterfaces.sol";
import "./WednesdayClubPost.sol";
import "./WednesdayClubComment.sol";
import "./WednesdayClubUser.sol";

contract WednesdayClub is Ownable, Destructible, Pausable, WednesdayClubPost, WednesdayClubComment, WednesdayClubUser {

    //onlyWednesdays Modifier
    modifier onlyWednesdays() {
        //require true only for testing
        //require(true);
        uint8 dayOfWeek = uint8((now / 86400 + 4) % 7);
        require(dayOfWeek == 3);
        _;
    }

    modifier whenNotSuspended() {
        require(hasSuspensionElapsed());
        _;
    }

    modifier whenTimeElapsedPost() {
        require(hasElapsedPost());
        _;
    }

    modifier whenTimeElapsedComment() {
        require(hasElapsedComment());
        _;
    }

    // WednesdayCoin contract being held
    WednesdayCoin public wednesdayCoin;

    //constructor
    constructor() public {
        //for testing -- 0xEDFc38FEd24F14aca994C47AF95A14a46FBbAA16
        wednesdayCoin = WednesdayCoin(0x7848ae8F19671Dc05966dafBeFbBbb0308BDfAbD);
        amountForPost = 10000000000000000000000; //10k
        amountForComment = 1000000000000000000000; //1k
        postInterval = 10 minutes;
        commentInterval = 5 minutes;
        minimumToLikePost = 1000000000000000000000; //1k
        minimumToLikeComment = 100000000000000000000; //100
        minimumForFollow = 100000000000000000000; //100
        minimumForReporting = 100000000000000000000; //100
        reportInterval = 10 minutes;
    }

    /*****************************************************************************************
     * Posts logic - add, like, report, delete
     * ***************************************************************************************/
    // Adds a new post
    function writePost(uint256 _id, uint256 _value, string _content, string _media) public onlyWednesdays whenNotPaused whenNotSuspended whenTimeElapsedPost {
        require(amountForPost == _value);
        require(bytes(_content).length > 0 || bytes(_media).length > 0);
        _id = uint256(keccak256(_id, now, blockhash(block.number - 1), block.coinbase));
        //for create
        if (wednesdayCoin.transferFrom(msg.sender, this, _value)) {
            emit PostContent(_id, _content, _media);
            Post memory post = Post(_id, msg.sender, 0, 0, now, 0);
            userPosts[msg.sender].push(_id);
            posts[_id] = post;
            postIds.push(_id);
            postTime[msg.sender] = now;
        } else {
            revert();
        }
    }

    function likePost(uint256 _id, uint256 _value) public onlyWednesdays whenNotPaused whenNotSuspended {
        require(_value >= minimumToLikePost);
        //ensure that post exists
        if (posts[_id].id == _id) {
            //shouldnt be able to like your own post
            require(posts[_id].poster != msg.sender);
            if (wednesdayCoin.transferFrom(msg.sender, posts[_id].poster, _value)) {
                posts[_id].value += _value;
                posts[_id].likes++;
            } else {
                revert();
            }
        }
    }

    function reportPost(uint256 _id, uint256 _value) public onlyWednesdays whenNotPaused whenNotSuspended {
        require(hasElapsedReport());
        //ensure that post exists
        if (posts[_id].id == _id) {
            //shouldnt be able to report your own post
            require(posts[_id].poster != msg.sender);
            if (wednesdayCoin.transferFrom(msg.sender, this, _value)) {
                posts[_id].reportCount++;
                reportTime[msg.sender] = now;
            } else {
                revert();
            }
        }
    }

    //delete a user post
    function deleteUserPost(address _user, uint256 _id) public onlyOwner {
        for(uint i = 0; i < userPosts[_user].length; i++) {
            if(userPosts[_user][i] == _id){
                delete userPosts[_user][i];
            }
        }
    }

    //delete a public post
    function deletePublicPost(uint256 _id) public onlyOwner {
        if(posts[_id].id == _id){
            delete posts[_id];
        }
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
    // deleteAllPosts from PostIds
    function deleteAllPosts() public onlyOwner {
        deleteAllPosts(postIds.length);
    }

    // deleteAllPosts in groups i.e. delete 100, then 100 again, etc - for saving on gas and incase to many
    function deleteAllPosts(uint256 amountToDelete) public onlyOwner {
        for(uint i = 0; i < amountToDelete; i++) {
            address poster = posts[postIds[i]].poster;
            deleteUserPost(poster, posts[postIds[i]].id);
            deletePublicPost(posts[postIds[i]].id);
            deleteIdFromPostIds(posts[postIds[i]].id);
        }
    }

    //to make it easier this one calls all delete functions
    function deletePost(address _user, uint256 _id) public onlyOwner {
        deleteUserPost(_user, _id);
        deletePublicPost(_id);
        deleteIdFromPostIds(_id);
    }

    /*****************************************************************************************
     * Comments logic - add, like, report, delete
     * ***************************************************************************************/
    // Adds a new comment
    function writeComment(uint256 _id, uint256 _parentId, uint256 _value, string _content, string _media) public onlyWednesdays whenNotPaused whenNotSuspended whenTimeElapsedComment {
        require(amountForComment == _value);
        require(bytes(_content).length > 0 || bytes(_media).length > 0);
        _id = uint256(keccak256(_id, now, blockhash(block.number - 1), block.coinbase));
        //for create
        if (wednesdayCoin.transferFrom(msg.sender, posts[_parentId].poster, _value)) {
            emit CommentContent(_id, _content, _media);
            Comment memory comment = Comment(_id, _parentId, msg.sender, 0, 0, now, 0);
            userComments[msg.sender].push(_id);
            comments[_id] = comment;
            postComments[_parentId].push(_id);
            postTime[msg.sender] = now;
        } else {
            revert();
        }
    }

    function likeComment(uint256 _id, uint256 _value) public onlyWednesdays whenNotPaused whenNotSuspended {
        require(_value >= minimumToLikeComment);
        //ensure that post exists
        if (comments[_id].id == _id) {
            //shouldnt be able to like your own post
            require(comments[_id].commenter != msg.sender);
            if (wednesdayCoin.transferFrom(msg.sender, comments[_id].commenter, _value)) {
                comments[_id].value += _value;
                comments[_id].likes++;
            } else {
                revert();
            }
        }
    }

    function reportComment(uint256 _id, uint256 _value) public onlyWednesdays whenNotPaused whenNotSuspended {
        require(hasElapsedReport());
        //ensure that post exists
        if (comments[_id].id == _id) {
            //shouldnt be able to report your own post
            require(comments[_id].commenter != msg.sender);
            if (wednesdayCoin.transferFrom(msg.sender, this, _value)) {
                comments[_id].reportCount++;
                reportTime[msg.sender] = now;
            } else {
                revert();
            }
        }
    }

    //delete a user comment
    function deleteUserComment(address _user, uint256 _id) public onlyOwner {
        for(uint i = 0; i < userComments[_user].length; i++) {
            if(userComments[_user][i] == _id){
                delete userComments[_user][i];
            }
        }
    }

    //delete a public comment
    function deletePublicComment(uint256 _id) public onlyOwner {
        if(comments[_id].id == _id){
            delete comments[_id];
        }
    }

    //to make it easier this one calls all delete functions
    function deleteComment(address _user, uint256 _id) public onlyOwner {
        deleteUserComment(_user, _id);
        deletePublicComment(_id);
    }

    /*****************************************************************************************
     * User logic - add/update profile info
     * ***************************************************************************************/

    function updateProfile(string username, string about, string profilePic) public onlyWednesdays whenNotPaused whenNotSuspended {
        if (users[msg.sender].id != msg.sender) {
            User memory user = User(msg.sender, '', '', '');
            users[msg.sender] = user;
        }
        if (bytes(username).length > 0) {
            users[msg.sender].username = username;
        }
        if (bytes(about).length > 0) {
            users[msg.sender].about = about;
        }
        if (bytes(profilePic).length > 0) {
            users[msg.sender].profilePic = profilePic;
        }
    }


    /*****************************************************************************************
     * Following/Followers logic
     * ***************************************************************************************/

    function follow(address _address, uint256 _value) public onlyWednesdays whenNotPaused whenNotSuspended {
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

    function unfollow(address _address) public onlyWednesdays whenNotPaused whenNotSuspended {
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
    /*****************************************************************************************
     * Just in case logic
     * ***************************************************************************************/

    // Used for transferring any accidentally sent ERC20 Token by the owner only
    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }

    // Used for transferring any accidentally sent Ether by the owner only
    function transferEther(address dest, uint amount) public onlyOwner {
        dest.transfer(amount);
    }

}
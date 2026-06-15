component extends="Controller" {

	/**
	* View all Posts
	**/
	function index() {
		posts=model("Post").findAll();
	}

	/**
	* View Post
	**/
	function show() {
		post=model("Post").findByKey(params.key);
	}

	/**
	* Add New Post
	**/
	function new() {
		post=model("Post").new();
	}

	/**
	* Create Post
	**/
	function create() {
		post=model("Post").new(params.post);
		if(post.save()){
			redirectTo(route="post", key=post.id);
		} else {
			renderView(action="new");
		}
	}

	/**
	* Edit Post
	**/
	function edit() {
		post=model("Post").findByKey(params.key);
	}

	/**
	* Update Post
	**/
	function update() {
		post=model("Post").findByKey(params.key);
		if(post.update(params.post)){
			redirectTo(route="post", key=post.id);
		} else {
			renderView(action="edit");
		}
	}

	/**
	* Delete Post
	**/
	function delete() {
		post=model("Post").findByKey(params.key);
		post.delete();
		redirectTo(route="posts");
	}

}

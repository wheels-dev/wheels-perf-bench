component extends="Model" {

	function config() {

		validatesPresenceOf("title,body,views");

	}

}
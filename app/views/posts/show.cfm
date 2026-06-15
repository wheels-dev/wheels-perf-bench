<cfparam name="post" default="">
<cfoutput>
<h1>#post.title#</h1>
<p>
	<strong>Title:</strong> #encodeForHTML(post.title)#
</p>
<p>
	<strong>Body:</strong> #encodeForHTML(post.body)#
</p>
<p>
	<strong>Views:</strong> #encodeForHTML(post.views)#
</p>
<p>
	#linkTo(route="editPost", key=post.id, text="Edit")# ·
	#buttonTo(route="post", key=post.id, text="Delete", method="delete")# ·
	#linkTo(route="posts", text="← all posts")#
</p>
</cfoutput>

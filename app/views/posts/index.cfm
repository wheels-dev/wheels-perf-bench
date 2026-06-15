<cfparam name="posts" default="">
<cfoutput>
<h1>Posts</h1>
<p>#linkTo(route="newPost", text="New post")#</p>
<cfloop query="posts">
	<article>
		<h2>#linkTo(route="post", key=posts.id, text=posts.title)#</h2>
		<p>Title: #posts.title#</p>
		<p>Body: #posts.body#</p>
		<p>Views: #posts.views#</p>
	</article>
</cfloop>
</cfoutput>

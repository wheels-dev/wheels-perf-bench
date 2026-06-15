<cfparam name="post" default="">
<cfoutput>
#errorMessagesFor("post")#
<cfif IsNumeric(post.id ?: "")>
	#startFormTag(action="update", key=post.id, method="patch")#
<cfelse>
	#startFormTag(action="create")#
</cfif>
	#textField(objectName="post", property="title", label="Title")#
#textArea(objectName="post", property="body", label="Body")#
#textField(objectName="post", property="views", label="Views")#
	<button type="submit">Save</button>
#endFormTag()#
</cfoutput>

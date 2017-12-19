<%@ page language="java" pageEncoding="utf-8" contentType="text/html;charset=utf-8" %>
<%@ page trimDirectiveWhitespaces="true" %>

<%@page import="java.net.InetAddress" %>
<%@page import="org.json.simple.JSONObject" %>
<%@page import="org.json.simple.parser.JSONParser" %>
<%@page import="org.json.simple.parser.ParseException" %>
<%@page import="org.json.simple.JSONArray" %>
<%@page import="org.apache.commons.io.IOUtils" %>
<%@page import="java.util.*" %>

<%@include file="00_constants.jsp"%>
<%@include file="00_utility.jsp"%>

<%
request.setCharacterEncoding("utf-8");
response.setContentType("text/html;charset=utf-8");
response.setHeader("Pragma","no-cache"); 
response.setHeader("Cache-Control","no-cache"); 
response.setDateHeader("Expires", 0); 

out.clear();	//注意，一定要有out.clear();，要不然client端無法解析XML，會認為XML格式有問題

/*********************開始做事吧*********************/
JSONObject obj=new JSONObject();

String lineChannel		= nullToString(request.getParameter("lineChannel"), "");
String sRecepientType		= nullToString(request.getParameter("type"), "");
if (beEmpty(lineChannel) || beEmpty(sRecepientType)){
	obj.put("resultCode", gcResultCodeParametersNotEnough);
	obj.put("resultText", gcResultTextParametersNotEnough);
	out.print(obj);
	out.flush();
	return;
}

String sLineServerUrl = (sRecepientType.equals("push")?gcLineServerPushUrl:gcLineServerMulticastUrl);
String sLineAccessToken = "";

Hashtable	ht					= new Hashtable();
String		sResultCode			= gcResultCodeSuccess;
String		sResultText			= gcResultTextSuccess;

ht = getChannelProfile(lineChannel);
sResultCode = ht.get("ResultCode").toString();
sResultText = ht.get("ResultText").toString();

if (sResultCode.equals(gcResultCodeSuccess)){	//有Channel資料
	sLineAccessToken = ht.get("Channel_Access_Token").toString();
}else{	//沒資料或該Channel被停用
	obj.put("resultCode", sResultCode);
	obj.put("resultText", sResultText);
	out.print(obj);
	out.flush();
	return;
}	//if (sResultCode.equals(gcResultCodeSuccess)){	//有Channel資料

InputStream	is			= null;
String		contentStr	= "";

//取得POST內容

try {
	is = request.getInputStream();
	contentStr= IOUtils.toString(is, "utf-8");
} catch (IOException e) {
	e.printStackTrace();
	writeLog("error", "\nUnable to get request body: " + e.toString());
	return;
}

if (beEmpty(contentStr)){
	out.println("no content");
	writeLog("info", "Channel request received, content is empty, quit...");
	return;
}else{
	writeLog("debug", "Channel request received, content= " + contentStr);
}

//回傳 Line 訊息給客戶
String	sResponse	= "";
try
{
	URL u;
	u = new URL(sLineServerUrl);
	HttpURLConnection uc = (HttpURLConnection)u.openConnection();
	uc.setRequestProperty ("Content-Type", "application/json");
	//uc.setRequestProperty ("Authorization", "Bearer {" + sLineAccessToken + "}");
	uc.setRequestProperty ("Authorization", "Bearer " + sLineAccessToken);
	uc.setRequestProperty("contentType", "utf-8");
	uc.setRequestMethod("POST");
	uc.setDoOutput(true);
	uc.setDoInput(true);

	byte[] postData = contentStr.getBytes("UTF-8");	//避免中文亂碼問題
	OutputStream os = uc.getOutputStream();
	os.write(postData);
	os.close();

	InputStream in = uc.getInputStream();
	BufferedReader r = new BufferedReader(new InputStreamReader(in));
	StringBuffer buf = new StringBuffer();
	String line;
	while ((line = r.readLine())!=null) {
		buf.append(line);
	}
	in.close();
	sResponse = buf.toString();	//取得Line回應值
	
}catch (IOException e){ 
	sResponse = e.toString();
	writeLog("error", "Exception when send message to Line: " + e.toString());
}

if (notEmpty(sResponse) && sResponse.equals("{}")){
	writeLog("info", "Successfully send push message to Line!");
	sResultCode	= gcResultCodeSuccess;
	sResultText	= gcResultTextSuccess;
}else{
	writeLog("error", "Failed to send push message to Line: " + sResponse);
	sResultCode	= gcResultCodeUnknownError;
	sResultText	= sResponse;
}

obj.put("resultCode", sResultCode);
obj.put("resultText", sResultText);
out.print(obj);
out.flush();

%>
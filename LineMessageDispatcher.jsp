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

if (beEmpty(lineChannel)){
	obj.put("resultCode", gcResultCodeParametersNotEnough);
	obj.put("resultText", gcResultTextParametersNotEnough);
	out.print(obj);
	out.flush();
	return;
}

String sSignature = nullToString(request.getHeader("X-Line-Signature"), "");
writeLog("debug", "\n***********************************************************************************************");
writeLog("debug", "Channel Name= " + lineChannel);
writeLog("debug", "X-Line-Signature= " + sSignature);

String sSecretKey = "";
String sServiceUrl = "";

Hashtable	ht					= new Hashtable();
String		sResultCode			= gcResultCodeSuccess;
String		sResultText			= gcResultTextSuccess;

ht = getChannelProfile(lineChannel);
sResultCode = ht.get("ResultCode").toString();
sResultText = ht.get("ResultText").toString();

if (sResultCode.equals(gcResultCodeSuccess)){	//有Channel資料
	sSecretKey = ht.get("Channel_Secret").toString();
	sServiceUrl = ht.get("Service_Url").toString();
}else{	//沒資料或該Channel被停用
	writeLog("debug", "Unable to get Channel settings= " + sResultText);
	obj.put("resultCode", sResultCode);
	obj.put("resultText", sResultText);
	out.print(obj);
	out.flush();
	return;
}	//if (sResultCode.equals(gcResultCodeSuccess)){	//有Channel資料

InputStream	is			= null;
String		contentStr	= "";

//取得POST內容
//範例：{"events":[{"type":"message","replyToken":"8ae2399e5479413aad4da654b0779fec","source":{"userId":"Ue913331687d5757ccff454aab90f55cb","type":"user"},"timestamp":1508602936037,"message":{"type":"text","id":"6875441678650","text":"h"}}]}

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
	writeLog("info", "Line message received, content is empty, quit...");
	return;
}else{
	writeLog("debug", "Line message received, content= " + contentStr);
}

//比對 HTTP header 中的 Signature 是否符合
if (!compareLineSignature(sSignature, sSecretKey, contentStr)){
	obj.put("resultCode", gcResultCodeNoPriviledge);
	obj.put("resultText", gcResultTextNoPriviledge);
	out.print(obj);
	out.flush();
	return;
}	//if (!compareLineSignature(sSignature, sSecretKey, contentStr)){

obj.put("resultCode", sResultCode);
obj.put("resultText", sResultText);

out.print(obj);
out.flush();
out.close();


//轉傳給 Channel Service
String	sResponse	= "";
try
{
	URL u;
	u = new URL(sServiceUrl + lineChannel);
	HttpURLConnection uc = (HttpURLConnection)u.openConnection();
	uc.setRequestProperty ("Content-Type", "application/json");
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
	sResponse = buf.toString();	//取得回應值
	
}catch (IOException e){ 
	sResponse = e.toString();
	writeLog("error", "Exception when send message to channel server: " + e.toString());
}

//if (notEmpty(sResponse) && sResponse.indexOf(gcResultCodeSuccess)>0 && sResponse.indexOf(gcResultTextSuccess)>0){
if (notEmpty(sResponse) && sResponse.indexOf(gcResultCodeSuccess)>0){
	writeLog("info", "Successfully send request message to channel server!");
}else{
	writeLog("error", "Failed to send request message to channel server: " + sResponse);
}

%>
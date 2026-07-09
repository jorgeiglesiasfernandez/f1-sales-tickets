<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%
    // Redirect to the Struts dashboard action.
    // Liberty forwards the welcome-file request before Struts initialises the
    // action context, so using a plain JSP redirect avoids the
    // "no action mapped for name ''" error on Liberty.
    response.sendRedirect(request.getContextPath() + "/dashboard");
%>

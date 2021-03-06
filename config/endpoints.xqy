xquery version "1.0-ml";

module namespace endpoints="http://marklogic.com/mljson/endpoints";

import module namespace rest="http://marklogic.com/appservices/rest" at "/data/lib/rest/rest.xqy";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare option xdmp:mapping "false";

declare variable $endpoints:ENDPOINTS as element(rest:options) :=
<options xmlns="http://marklogic.com/appservices/rest">
    <!-- Manage documents in the database -->
    <request uri="^/data/store/(.+)$" endpoint="/data/store.xqy" user-params="allow">
        <uri-param name="uri" as="string">$1</uri-param>
        <http method="GET"/>
        <http method="POST"/>
        <http method="PUT"/>
        <http method="DELETE"/>
    </request>

    <!-- Custom queries -->
    <request uri="^/data/customquery(/)?$" endpoint="/data/customquery.xqy">
        <param name="q" required="true"/>
        <param name="include" repeatable="true" required="false"/>
        <http method="GET"/>
        <http method="POST"/>
    </request>

    <!-- Query strings -->
    <request uri="^/data/query(/|/(\d+)/?|/(\d+)/(\d+)/?)?$" endpoint="/data/query.xqy">
        <uri-param name="__MLJSONURL__:index">$2</uri-param>
        <uri-param name="__MLJSONURL__:start">$3</uri-param>
        <uri-param name="__MLJSONURL__:end">$4</uri-param>
        <param name="q" required="true"/>
        <param name="include" repeatable="true" required="false"/>
    </request>

    <!-- Key value queryies -->
    <request uri="^/data/kvquery(/|/(\d+)/?|/(\d+)/(\d+)/?)?$" endpoint="/data/kvquery.xqy" user-params="allow">
        <uri-param name="__MLJSONURL__:index">$2</uri-param>
        <uri-param name="__MLJSONURL__:start">$3</uri-param>
        <uri-param name="__MLJSONURL__:end">$4</uri-param>
    </request>

    <!-- Info request -->
    <request uri="^/data/info(/)?$" endpoint="/data/info.xqy" user-params="ignore"/>

    <request uri="^/data/manage/field/([A-Za-z0-9-]+)(/)?$" endpoint="/data/manage/field.xqy" user-params="allow">
        <uri-param name="name" as="string">$1</uri-param>
        <http method="GET"/>
        <http method="POST"/>
        <http method="PUT"/>
        <http method="DELETE"/>
    </request>

    <request uri="^/data/manage/range/([A-Za-z0-9_-]+)(/)?$" endpoint="/data/manage/range.xqy" user-params="allow">
        <uri-param name="name" as="string">$1</uri-param>
        <http method="GET"/>
        <http method="POST">
            <param name="key" required="true"/>
            <param name="type" required="true"/>
            <param name="operator" required="true"/>
        </http>
        <http method="PUT">
            <param name="key" required="true"/>
            <param name="type" required="true"/>
            <param name="operator" required="true"/>
        </http>
        <http method="DELETE"/>
    </request>

    <request uri="^/data/manage/map/([A-Za-z0-9_-]+)(/)?$" endpoint="/data/manage/map.xqy" user-params="allow">
        <uri-param name="name" as="string">$1</uri-param>
        <http method="GET"/>
        <http method="POST">
            <param name="key" required="true"/>
            <param name="mode" required="true" values="contains|equality"/>
        </http>
        <http method="PUT">
            <param name="key" required="true"/>
            <param name="mode" required="true" values="contains|equality"/>
        </http>
        <http method="DELETE"/>
    </request>
</options>;

declare function endpoints:options(
) as element(rest:options)
{
    $ENDPOINTS
};

declare function endpoints:request(
    $module as xs:string
) as element(rest:request)?
{
    ($ENDPOINTS/rest:request[@endpoint = $module])[1]
};

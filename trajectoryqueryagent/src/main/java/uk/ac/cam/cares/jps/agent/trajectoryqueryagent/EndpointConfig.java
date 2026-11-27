package uk.ac.cam.cares.jps.agent.trajectoryqueryagent;

import com.cmclinnovations.stack.clients.blazegraph.BlazegraphClient;
import com.cmclinnovations.stack.clients.blazegraph.BlazegraphEndpointConfig;
import com.cmclinnovations.stack.clients.postgis.PostGISClient;
import com.cmclinnovations.stack.clients.postgis.PostGISEndpointConfig;

public class EndpointConfig {
    private String kgurl;

    private String dbuser;
    private String dbpassword;
    private PostGISEndpointConfig postGISEndpointConfig;

    public EndpointConfig() {
        BlazegraphClient.getInstance().readEndpointConfig();
        BlazegraphEndpointConfig blazegraphEndpointConfig = BlazegraphClient.getInstance().readEndpointConfig();
        this.kgurl = blazegraphEndpointConfig.getUrl("kb");

        postGISEndpointConfig = PostGISClient.getInstance().readEndpointConfig();
        this.dbuser = postGISEndpointConfig.getUsername();
        this.dbpassword = postGISEndpointConfig.getPassword();
    }

    public String getKgurl() {
        return this.kgurl;
    }

    public String getDburl() {
        return postGISEndpointConfig.getJdbcURL("postgres");
    }

    public String getDburl(String database) {
        return postGISEndpointConfig.getJdbcURL(database);
    }

    public String getDbuser() {
        return this.dbuser;
    }

    public String getDbpassword() {
        return this.dbpassword;
    }
}

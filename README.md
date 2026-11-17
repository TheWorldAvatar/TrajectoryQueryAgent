# TrajectoryQueryAgent

TrajectoryQueryAgent is an agent that handles trajectory related tasks. It currently supports the following functions through the endpoints:

- `/createLayer`: create geoserver layer and postgis functions for the geoserver query (POST)
- `/getDatesWithData`: get dates that have trajectory data

## Requirements

Launch [stack](https://github.com/cambridge-cares/TheWorldAvatar/tree/main/Deploy/stacks/dynamic/stack-manager) with the default containers and the following additional containers:

- information from [SensorLoggerMobileAppAgent](https://github.com/cambridge-cares/TheWorldAvatar/tree/main/Agents/SensorLoggerMobileAppAgent) to be instantiated

## Deploy

### Retrieving TrajectoryQueryAgent's image

The TrajectoryQueryAgent should be pulled automatically with the stack-manager, if not you can pull the latest version from [cambridge_cares package](https://github.com/orgs/cambridge-cares/packages/container/package/trajectoryqueryagent) using `docker pull ghcr.io/cambridge-cares/trajectoryqueryagent:<LATEST-VERSION>`

### Starting with the stack-manager

The agent has been implemented to work in the stack, which requires the TrajectoryQueryAgent Docker container to be deployed in the stack. To do so, place [trajectoryqueryagent.json](stack-manager-config/inputs/config/services/trajectoryqueryagent.json) in the [stack-manager config directory].

Then, run `./stack.sh start <STACK NAME>` in the [stack-manager] main folder. This will spin up the agent in the stack.

## Develop and Debug

### Credentials

The docker image uses TheWorldAvatar maven repository (`https://maven.pkg.github.com/cambridge-cares/TheWorldAvatar/`).
You will need to provide your credentials (GitHub username/personal access token) in single-word text files as follows:

```
./credentials/
        repo_username.txt
        repo_password.txt
```

### Building Docker Image

In the same directory as this README, run `./stack.sh build`. This will build the TrajectoryQueryAgent local Docker Image.

### Spinning up with stack-manager

To debug the agent, replace [`trajectoryqueryagent-debug.json`](stack-manager-config/inputs/config/services/trajectoryqueryagent-debug.json) instead of [`trajectoryqueryagent.json`](stack-manager-config/inputs/config/services/trajectoryqueryagent.json) in the [stack-manager config directory].

Spin up with `./stack.sh start <STACK NAME>` in the [stack-manager]'s main folder.
The debugger port will be available at 5005.

## Routes

### 1. /createLayer

Send a POST. No authentication or input parameters are required for this route.

```bash
curl -X POST "http://localhost:3838/trajectoryqueryagent/createLayer"
```

Currently, four layers are created in the twa workspace. Unix timestamp in milliseconds is used for the layers.

1. trajectoryDeviceId
2. trajectoryUserId
3. bufferedLineDeviceId
4. trajectoryUserIdByActivity

In the following sections, attributes refer to variables in the SQL view table, SQL view parameters refer to parameters passed from the URL and substituted in the SQL view, e.g. %device_id% in [line layer (device id)].

SQL view parameters are specified as key:value pairs separated by semicolons in the viewparams parameter in the URL, e.g. `viewparams=p1:v1;p2:v2`, refer to the [official documentation](https://docs.geoserver.org/main/en/user/data/database/sqlview.html) for more information

#### trajectoryDeviceId layer

This layer consists of line segments with associated speed, altitude and bearing values, so that styling is possible. Refer to [line layer (device id)].

Attributes: time, speed, altitude, bearing, iri  
View parameters: device_id

#### trajectoryUserId

This layer produces one line per contiguous trip/stay segment within the requested
time range. Refer to [line layer (user id)].

Attributes: start_time, end_time, geom, iri, session_id, trip, id, distance_traveled

View parameters: user_id, lowerbound (optional), upperbound (optional)

`lowerbound` and `upperbound` are Unix milliseconds, with `0` meaning unbounded.
Bounds are exclusive and apply to points before trip segmentation and aggregation.

#### bufferedLineDeviceId

To be used in conjunction with trajectoryDeviceId, adds a 100 m buffer to the original line. lowerbound and upperbound are Unix timestamps in milliseconds.

Attributes: iri  
View parameters: device_id, lowerbound (optional), upperbound (optional)

### 2. /getDatesWithData

This route is primarily used by the timeline app, this route requires two additional environment variables and an additional header with the JSON web token.

Environment variables:

1. KEYCLOAK_SERVER
    - Base URL of KeyCloak server that generates the JSON web token for verification

2. KEYCLOAK_REALM
    - Name of KeyCloak realm of the requesting users

Needs the `Authorization` header in the following form:

`Authorization: Bearer <JWT_TOKEN>`

Only one `/getDatesWithData` request per authenticated user can run at a time within each application instance. Overlapping requests for the same user return HTTP 429 with `{"message":"A dates request is already in progress for this user"}`. The slot is released when the request finishes, including on failure; requests from different users can run concurrently. This limit is not shared across replicas.

Parameters required:

1. timezone (refer [here](https://www.postgresql.org/docs/current/view-pg-timezone-names.html) for permissible names)

Response given in the form of

```json
{"result":[{"month":1,"year":2024,"days":"{1,2,3}"}],"message":"Succeed"}
```

[stack-manager]: https://github.com/cambridge-cares/TheWorldAvatar/tree/main/Deploy/stacks/dynamic/stack-manager
[stack-manager config directory]: https://github.com/cambridge-cares/TheWorldAvatar/tree/main/Deploy/stacks/dynamic/stack-manager/inputs/config/services
[line layer (device id)]: ./trajectoryqueryagent/src/main/resources/line_layer_device_id.sql
[line layer (user id)]: ./trajectoryqueryagent/src/main/resources/line_layer_user_id.sql

## Shared trajectory storage

Layers read from tables maintained by the SensorLoggerMobileAppAgent.

If any point in a trajectory has a trip index, pending points without indices are hidden. Otherwise all points are displayed. Trip presence is checked before the display time bounds.

### Available-date cache

This agent shares the available date cache with the SensorLoggerMobileAppAgent.

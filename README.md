It's an app! It is a todo list. It's me tooling around with some technologies. Right now, it's a monolith MERN app. I deployed it to an ec2 and visited it on my phone. I want to make it microservices. For right now, I'm gonna run all three docker images on the same ec2.

The goal is to keep everything free tier accessible
 
## Build the Docker images

`sudo docker build -f Dockerfile.api -t api .`
`sudo docker build -f Dockerfile.client -t client .`

## Run the docker images
 - run the two that we just built, and also mongo 4.4
 - I chose 4.4 because mongo 5 requires a special fancy processor, so this should be more compatible. 
 - ya gotta run it in order. Mongo, then the api, then the client

`sudo docker run -p 27017:27017 mongo:4.4`
`sudo docker run -p 5000:5000 api`
`sudo docker run -p 3000:3000 client`

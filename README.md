# Free.ly
_It's an application that I am deploying using different methods_

Demonstrations of applications and CI/CD deployed using AWS tools exclusively available through the free tier. We introduce complexity step by step. From running locally to various cloud based deployments.  

### Run Locally
You know the vibes. Make sure you have downloaded mongodb. Note: step 1 and two aredifferent processes. So run them in different terminals. Or run them in the background if you're feeling spicy. `npm start&` 

1. Start the api. 
`npm install`
`npm start`

2. Start the client.  
`cd client`
`npm install`
`npm client`

3. Visit http://localhost:3000/. On chrome, I had to run a special setting. Visit (chrome://net-internals/#hsts)[chrome://net-internals/#hsts], type localhost into "Delete domain security policies", and click delete.  

### Directly to EC2
Use the EC2 just like someone's computer. 

1. Provision EC2. set promiscuous network traffic connection rules. I did this through the console, but I would like to write a terraform for it as well. 

2. Transfer code to EC2. One directory above the repository (`cd ..`), run `tar -czvf mern app.zip`. Secure copy the zip onto the EC2. You man want to grab the url of your instance from the AWS console. From your repository root, run: 
`cd ..`
`tar -czvf mern app.zip`
`scp -r -i "antq.pem" app.zip  ec2-user@ec2-3-145-76-198.us-east-2.compute.amazonaws.com:~ 

### Locally with Docker files
Here, we introduce Docker. A note. I installed docker on a chromebook, and my configuration just so happened to require sudo for docker commands. If you are able to run docker without sudo priveleges, go for it! 

1. Build The Docker images. We build one image for the api and one for the client. From your repository root, run:  
`sudo docker build -f Dockerfile.api -t api .`
`sudo docker build -f Dockerfile.client -t client .`

2. Run the images. We will run MongoDB from a docker image. We expose ports with the -p option. In order, in separate terminals or as separate background processes:  
`sudo docker run -p 27017:27017 mongo:4.4`
`sudo docker run -p 5000:5000 api`
`sudo docker run -p 3000:3000 client`

3. Visit localhost:3000

### EC2 with Docker ( Under Development )

### Elastic Container Service with Terraform ( Under Development ) 
Put them images up in that cloud!  

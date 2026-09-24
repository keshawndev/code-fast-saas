# CodeFast SaaS: Cloud Deployment Portfolio

One or two sentences: what the app is (a feedback board where users
post and upvote ideas) and what this repo demonstrates (taking an app
from local development to a containerized, CI/CD-deployed cloud service).                                                                      

## Tech Stack
App: Next.js 15, MongoDB, Auth.js, Stripe
Infrastructure: Docker, Docker Compose (more added each phase)                                                                                 

## Project Roadmap
- [x] Phase 1: Containerization
- [ ] Phase 2: CI with GitHub Actions
- [ ] Phase 3: AWS infrastructure with Terraform                                                                                               
- [ ] Phase 4: Continuous deployment (dev → staging → prod)                                                                                    
- [ ] Phase 5: Monitoring and alerting                                                                                                         

## Branching Strategy
Explain dev → staging → prod in your words: work happens on feature
branches, merges into dev through PRs, then gets promoted by PR.

## Run It Locally
Prerequisites: Docker Desktop, Stripe CLI
Numbered steps:                                                                                                                                
1. clone
2. cp .env.example .env.local, then fill in values
3. docker compose up --build                                                                                                                   
4. stripe listen --forward-to localhost:3000/api/webhook                                                                                       
5. open http://localhost:3000                                                                                                                  

## Phase 1: Containerization
The section interviewers care most about. Short bullets:
- Multi-stage build: 1.06 GB → 336 MB final image
- Standalone output: 439 MB node_modules → 66 MB runtime                                                                                       
- Runs as a non-root user                                                                                                                      
- /api/health endpoint + Docker HEALTHCHECK                                                                                                    
- Build once, configure at runtime: no secrets in the image                                                                                    
(mention the lazy MongoDB connection fix)                                                                                                    

### Problems I Solved
2–4 short entries: problem → cause → fix. You have great ones:
- Build failed without MONGO_URI → connection happened at import → made it lazy                                                                
- Container unhealthy → localhost resolved to IPv6 → used 127.0.0.1                                                                            
- OAuth failed in container → Auth.js used 0.0.0.0 → set AUTH_URL                                                                              
- Subscriptions didn't activate → Stripe can't reach localhost → Stripe CLI                                                                    

## Known Issues
- Board share link is hardcoded to one domain
- /dashboard crashes on a null session in one case          
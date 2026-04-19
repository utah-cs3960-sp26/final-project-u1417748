# Pocket Hoops

## YouTube Video Link:

https://youtu.be/nu1xFx_FX7k


## Proposal (Week 12)

### What are you going to build? What are the features you intend to show off? What kind of agentic loop are you going to use to make this happen? What will be the feedback mechanisms that you will tell the agent to use, to ensure a quality product?


I want to build a retro, arcade style, basketball game. The core mechanic would be that you only play offense, you control the person with the ball every possession, you can swipe to pass to teammates (5v5) who dynamically move around based on the player with the balls position. You can shoot with a timing based swipe and release method. When you score or miss, the opponent's possession is simulated automatically based on their roster ratings and the ball comes right back to you on offense. This is to keep the pacing fast and gameplay focused solely on the offense mechanics, helping to lower the scope of this project to the time permitted. For the features I want to show off, I'd want to have a working shooting mechanic with a physics based ball arc and rim collisions, a working teammate movement system, and a working simulation for when the computer team has possession of the ball using ratings to determine outcomes. A stretch goal would be a fast break mechanic to give 2 on 1 opportunities.


For my agentic loop, I'll likely be using mostly AMP with possibly some Codex to generate the frame, the physics setup, and the UI while I will focus on tuning the gameplay to feel arcady and the logic that the AI probably won't get right on it's own. Before each task, I'll give AMP a structured checklist, what tasks to perform, what the expected behavior should look like, and what constraints to follow. For feedback, I'll have AMP run a build after every change to catch compile errors immediately and I'll maintain a testing.md or similar file that describes test cases to check for. 

## Responses (Week 13)

### What's working so far on your project? What are your concrete plans for the next week? What are the smartest and dumbest thing your agent loop did this week? If you're using Amp, link to the relevant threads. What did you change to stop the agent from doing that dumb thing again?


So far, the gameplay and visual aspect of my project is working somewhat well. The user can pass the ball, shoot it based off a timer, and miss the shot if it's bad. There were a lot of troubles visually for AMP because it seemed a lot more reluctant to run the code and use visuals to help itself debug, so instead, I switched to Codex. I would instruct Codex to run the game and to see its placements of visuals to make sure they align with the details I was describing. 

The dumbest things my agent loop did this week were assuming it knows the details of how items were drawn and the placements inside of those drawings. For example, if a player shot the ball, it would count as a score even if the ball didn't visually go through the hoop and instead was above it. To prevent codex from doing this again, I told it to place it as close as it could predict accurately and then to wait for me to help give it fine details on the placements such as: "lower the end point of the shot by 100 pixels" which worked well and was suprisingly faster then letting Codex try to figure it out itself. It continues to start with rough estimates and tell itself "that's perfect" which causes a lot of visual bugs early on. 

The smartest thing its done is get the arch for a more arcadic style shot right while still being accurate. Since it's a top down view, a shot would likely just look like a straight line, but I wanted to dramaticize the effect so adding a big arch and curve to the shot which AMP/Codex were able to achieve very well through creating a physics based environment. 

## Responses (Week 14)


The final product is very similar to the proposal from a week 12. This finished product is still a pixel, retro, themed basketball game that has the core mechanics of movement, passing, and shooting. It has an automatic defense system and a simulated offense for the opponents team to help the game feel much more fluid and that player constantly be playing offense rather then bothering with any defense. I could not reach my stretch goal of a fast break mechanic as I ran into many bugs when implementing the other parts so I had to prioritize the core functionality and other aspects of the game that would make it feel more complete. I also added a "shop" which wasn't in the original proposal as it shows a way the game could be built on and in the future add a leveling system. 

The agentic methodologies I used also differed from the original proposal. I ended up using Codex a lot more then AMP because Codex has a "planning" mode which handled more complex and big implementations better since it would ask clarifying questions which would catch some obvious edge cases. 

For the agentic loop, I initially started with AMP and the while loop with a PROMPT.md file like how we did with the simulation project, however, it quickly ran into a lot of issues, especially revolving around the ball trajectories when shooting. This cause me to re-plan and start with Codex which has a planning mode and I found building in smaller steps with each planned out and ran through CodeX performed better then AMP. This was because AMP decided anything I said was truth and wouldn't question an approach while CodeX would ask me for clarifications if I proposed an approach that would contradict an already implemented feature. So my method was a lot of individual planned out threads working concurrently on very separate features to cover the most amount of ground while not breaking what another agent wrote. 

You can view it here:

https://youtu.be/nu1xFx_FX7k


------

## Run

Open the project in Godot 4.6.x or run:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --path .
```

Headless automated tests:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd
```

## Docs

- `docs/PROJECT_BRIEF.md`
- `docs/GAMEPLAY_SPEC.md`
- `docs/ARCHITECTURE.md`
- `docs/DECISIONS.md`
- `docs/TEST_PLAN.md`
- `docs/KNOWN_ISSUES.md`
- `docs/WORKLOG.md`
- `docs/TEST_RESULTS.md`

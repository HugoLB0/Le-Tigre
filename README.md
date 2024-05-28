
<a name="readme-top"></a>

<br />
<div align="center">


<h1 align="center">Le Tigre</h1>

</div>



<!-- TABLE OF CONTENTS -->

  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites--installation">Prerequisites</a></li>
        <li><a href="#run-it">Run it</a></li>
      </ul>
    </li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#built-by">Built by</a></li>
  </ol>




<!-- ABOUT THE PROJECT -->
## About The Project

Le Tigre integrates speech recognition, vision, and text-to-speech capabilities to offer a comprehensive multimodal AI solution. It can process and interpret audio inputs, detect and analyze visual elements, and generate descriptive and contextual text outputs, all in real time.
This project was built in 24h during the Celebral Valley X Mistral AI hackathon. [Check out the project on Devpost!](https://devpost.com/software/le-tigre)

https://github.com/HugoLB0/Le-Tigre/assets/66400773/c73f68c6-ba8f-48c6-b84f-651f861906a0


### Built With

  

<!-- GETTING STARTED -->
## Getting Started

This is an example of how you may give instructions on setting up your project locally.
To get a local copy up and running follow these simple example steps.

### Prerequisites & Installation

You will need to install a few stuff. Because we lost the access to the ssh server with GPU, the fine tuned model weight are lost. But you can still use it with a local LLM via [Ollama](https://ollama.com/library/mistral:v0.3/blobs/43070e2d4e53). We tried with the Mistral 7B v0.3 model
* first install some python libraries. I recommend you to create a new virtualenv.
  ```sh
  pip install -r requirements.txt
  ```
* optional: we used langchain which allows you to switch between a lot of LLMs. If you want to use local models with Ollama, run the following command to install it. But feel free to modify the backend if you want to switch LLMs provider. Also beware of models specific instruction tokens
  ```sh
  ollama pull mistral:v0.3
  ```
* if you want to use it with the IOS app, you will have to get a openai api key to setup whisper stt and a eleven labs api key for stt. 

### Run it

After installing all the prerequisites and the LLM, you will have to setup the backend 
1. Get OpenAI api key and Eleven Labs api key for the voice part of the ios app
2. Run the flask backend
   ```sh
   python main.py
   ```
3. make sure to update the IOS app server_url 
4. Build the IOS app with Xcode 




<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request





<!-- LICENSE -->
## License

Distributed under the MIT License. See `LICENSE.txt` for more information.




<!-- CONTACT -->
## Built by

Hugo Le Belzic - [@hugolb05](https://twitter.com/hugolb05) - hlebelzic@ef.stationf.co

Darya Todoskova Zorkot - [@linkedin](https://www.linkedin.com/in/darya-todoskova-zorkot-3005181b8) - zorkotdasha@gmail.com







from langchain_core.prompts import ChatPromptTemplate
from langchain_community.chat_models import ChatOllama
from langchain_core.messages import AIMessage, HumanMessage
from langchain.agents import AgentExecutor, create_json_chat_agent
from langchain_community.tools import DuckDuckGoSearchRun
import asyncio
from dotenv import load_dotenv
from langchain.memory import ConversationBufferMemory
import langsmith
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder




class LLM_image:
    def __init__(self):
        load_dotenv()

    def load_model(self):
        self.model = ChatOllama(
            model='mistral:v0.3',
            temperature=0.4)

        self.system_prompt = """
        <s>[INST] <<SYS>>
        Your role is to given a json containing a yolo model (object detection) output and an OCR text extraction output, 
        provide a detailed description of the image. 
        IMPORTANT: 
        - the provided image is the user camera stream. 
        - The provided image size is 1920x1080. 
        - You should try to describe as precisely as possible.
        - DO NOT OUTPUT ANY CONFIDENCES SCORE OR POSITION.
        - You should only output the text description, and nothing else.
        - note that Human Face, Men or Female, and Person correspond to the same object, which is a person.
        <</SYS>>[/INST]"""
        self.prompt = ChatPromptTemplate.from_messages([
            ("system", self.system_prompt),
            ("human", "<s>[INST]  {text} [/INST]"),
        ])
        self.chain = self.prompt | self.model
        return self.chain   

    async def execute_llm(self, input_: str, chain):
        return await chain.ainvoke({"text": input_})



class LLM_main:
    def __init__(self):
        load_dotenv()
        self.memory = ConversationBufferMemory(memory_key="chat_history")
        self.tools = [DuckDuckGoSearchRun()]
        self.chat_history = []

    def load_model(self):
        self.model = ChatOllama(
            model='mistral:v0.3', 
            temperature=0.5
        )




        self.system = '''<s>[INST] <<SYS>> Your name is Le Tigre, you are a multimodal AI assistant, built by two amazing founders.
            Your name inspiration comes from 'Le Chat' of Mistral AI, because you are a fine tuned version that has now some kind of multi-modal capabilities.
            You are NOT a text-only model, you are a multimodal model.
            rules:
            - You DO NOT ALWAYS need to use the image to answer. 
            - DO NOT SAY you cannot see images. 
            - DO NOT answer anything not related to the query. 
            - If you didnt use the image content to answer, DONT MENTION it in your response.
            - If the user DO NOT excplicitly ask for you to 'see', or ask anything related to the image, you should NOT mention it in your final response.
            Your role is to answer the user query. <</SYS>>[/INST]'''

        self.human = ''''<s>[INST] <<SYS>> TOOLS
        ------
        Assistant can ask the user to use tools to look up information that may be helpful in             answering the users original question. The tools the human can use are:

        {tools}

        RESPONSE FORMAT INSTRUCTIONS
        ----------------------------

        When responding to me, please output a response in one of two formats:

        **Option 1:**
        Use this if you want the human to use a tool.
        Markdown code snippet formatted in the following schema:

        ```json
        {{
            "action": string, \ The action to take. Must be one of {tool_names}
            "action_input": string \ The input to the action
        }}
        ```

        **Option #2:**
        Use this if you want to respond directly to the human. Markdown code snippet formatted             in the following schema:

        ```json
        {{
            "action": "Final Answer",
            "action_input": string \ You should put what you want to return to use here
        }}
        ```

        USER'S INPUT
        --------------------
        Here is the user's input (remember to respond with a markdown code snippet of a json             blob with a single action, and NOTHING else):

        {input} <</SYS>>[/INST]'''

        self.prompt = ChatPromptTemplate.from_messages(
            [
                ("system", self.system),
                MessagesPlaceholder("chat_history", optional=True),
                ("human", self.human),
                MessagesPlaceholder("agent_scratchpad"),
            ]
        )
        #self.prompt = ChatPromptTemplate.from_messages([
        #    ("system", self.system_prompt),
        #    ("human", "<s>[INST] {text} [/INST]"),
        #])

        self.agent = create_json_chat_agent(
            llm=self.model.with_config({"tags": ["agent_llm"]}),
            tools=self.tools,
            prompt=self.prompt,
    )

        self.agent_executor = AgentExecutor(
            agent=self.agent,
            tools=self.tools, 
            verbose=True, 
            handle_parsing_errors=True
        ).with_config(
    {"run_name": "Agent"}
)
        return self.agent_executor
    
    async def execute_llm(self, input_: str, agent_executor):

        chunk = []
        async for chunk in self.agent_executor.astream(
            {"input": input_}
        ):
            self.chunks.append(chunk)

        response = "".join([c for c in chunk])

        self.chat_history.append(
            HumanMessage(content=input_),
            AIMessage(content=response)
        )

        return response


# To run the async function, you can use an event loop
# llm_image_instance = LLM_image()
# asyncio.run(llm_image_instance.execute_llm("hello, how are you?"))

# Example usage:
# llm_main_instance = LLM_main()
# chain = llm_main_instance.load_model()
# asyncio.run(llm_main_instance.execute_llm("What is the weather like today?", chain))


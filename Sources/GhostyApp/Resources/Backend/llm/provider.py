"""LLM provider factory — returns a LangChain BaseChatModel."""

from langchain_core.language_models.chat_models import BaseChatModel

from config import (
    GHOSTY_LLM_PROVIDER,
    GHOSTY_LLM_MODEL,
    OLLAMA_BASE_URL,
    OPENAI_API_KEY,
    ANTHROPIC_API_KEY,
)


def get_llm(
    provider: str | None = None,
    model: str | None = None,
    temperature: float = 0.1,
) -> BaseChatModel:
    """Return a chat model instance based on configuration.

    Override via env vars GHOSTY_LLM_PROVIDER / GHOSTY_LLM_MODEL,
    or pass provider/model directly.
    """
    provider = (provider or GHOSTY_LLM_PROVIDER).lower()
    model = model or GHOSTY_LLM_MODEL

    if provider == "ollama":
        from langchain_ollama import ChatOllama
        return ChatOllama(
            model=model,
            base_url=OLLAMA_BASE_URL,
            temperature=temperature,
            num_predict=1024,
        )

    if provider == "openai":
        from langchain_openai import ChatOpenAI
        return ChatOpenAI(
            model=model,
            api_key=OPENAI_API_KEY,
            temperature=temperature,
        )

    if provider == "anthropic":
        from langchain_anthropic import ChatAnthropic
        return ChatAnthropic(
            model=model,
            api_key=ANTHROPIC_API_KEY,
            temperature=temperature,
        )

    raise ValueError(f"Unknown LLM provider: {provider}")

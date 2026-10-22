"""Fund benchmark validation helpers independent of API/provider shapes."""


def is_fixed_income_fund_type(value: str | None) -> bool:
    normalized = (value or "").strip().lower().replace("_", " ").replace("-", " ")
    return any(marker in normalized for marker in ("fixed income", "درآمد ثابت"))

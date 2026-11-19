import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { CreateAccountScreen } from "./auth/CreateAccountScreen";
import { ResetScreen } from "./auth/ResetScreen";
import { SignInScreen } from "./auth/SignInScreen";
import { VerifyCodeScreen } from "./auth/VerifyCodeScreen";

export function App() {
  return (
    <BrowserRouter basename={import.meta.env.BASE_URL}>
      <Routes>
        <Route path="/sign-in" element={<SignInScreen />} />
        <Route path="/create-account" element={<CreateAccountScreen />} />
        <Route path="/verify" element={<VerifyCodeScreen />} />
        <Route path="/reset" element={<ResetScreen />} />
        <Route path="/" element={<main className="form-page"><h1>You’re signed in</h1></main>} />
        <Route path="*" element={<Navigate to="/sign-in" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

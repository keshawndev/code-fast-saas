"use client";

import axios from "axios";
import { useState } from "react";
import toast from "react-hot-toast";

const ButtonCheckout = () => {
  const [isLoading, setLoading] = useState(false);

  const handleSubscribe = async () => {
    if (isLoading) return;

    setLoading(true);

    try {
      const response = await axios.post("/api/billing/create-checkout", {
        successUrl: window.location.href + "/success",
        cancelUrl: window.location.href,
      });

      const checkoutUrl = response.data.url;

      console.log(checkoutUrl);

      window.location.href = checkoutUrl;
    } catch (error) {
      const errorMessage =
        error.response?.data?.error || error.message || "Something went wrong";

      toast.error(errorMessage);
      setLoading(false);
    }
  };

  return (
    <button className="btn btn-primary" onClick={() => handleSubscribe()}>
      {isLoading && (
        <span className="loading loading-spinner loading-xs"></span>
      )}
      Subscribe
    </button>
  );
};

export default ButtonCheckout;

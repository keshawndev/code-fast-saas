"use client";

import { useState, useEffect } from "react";
import axios from "axios";
import toast from "react-hot-toast";

const ButtonVote = ({ postId, initialVotes }) => {
  const localStorageKeyName = `codefastSaaS-hasVoted-${postId}`;
  const [isVoting, setIsVoting] = useState(false);
  const [hasVoted, setHasVoted] = useState(false);
  const [votesCounter, setVotesCounter] = useState(initialVotes);

  useEffect(() => {
    const hasVotedStoredValue = localStorage.getItem(localStorageKeyName);
    setHasVoted(hasVotedStoredValue === "true");
  }, []);

  const handleVote = async () => {
    if (isVoting) return;

    setIsVoting(true);

    try {
      if (hasVoted) {
        setHasVoted(false);
        setVotesCounter(votesCounter - 1);
        await axios.delete(`/api/vote?postId=${postId}`);
        localStorage.removeItem(localStorageKeyName);
      } else {
        setHasVoted(true);
        setVotesCounter(votesCounter + 1);
        await axios.post(`/api/vote?postId=${postId}`);
        localStorage.setItem(localStorageKeyName, "true");
      }
    } catch (error) {
      const errorMessage =
        error.response?.data?.error || error.message || "Something went wrong";

      toast.error(errorMessage);
    } finally {
      setIsVoting(false);
    }
  };

  return (
    <button
      className={` group btn min-w-[3rem] h-12 text-lg flex items-center justify-center ml-4 gap-2 ${
        hasVoted ? "btn-success" : "btn-primary"
      }`}
      onClick={handleVote}
    >
      <div className="flex-col items-center justify-items-center ">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          className="size-6 translate-y-0.3 group-hover:-translate-y-1"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth="2"
            d="M5 15l7-7 7 7"
          />
        </svg>
        <span className=" block text-xs -translate-y-1">{votesCounter}</span>
      </div>
    </button>
  );
};

export default ButtonVote;

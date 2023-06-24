function calculateLoveScore() {
  var name1 = document.getElementById("name1").value.toLowerCase();
  var name2 = document.getElementById("name2").value.toLowerCase();

  // Calculate love score
  var score = calculateScore(name1, name2);

  // Display the result
  var resultElement = document.getElementById("result");
  resultElement.innerHTML = getLoveMessage(score);
}

function calculateScore(name1, name2) {
  var combinedNames = name1 + name2;
  var score = 0;

  for (var i = 0; i < combinedNames.length; i++) {
    score += combinedNames.charCodeAt(i);
  }

  return Math.round((score % 101) / 1.01); // Calculate the percentage score
}

function getLoveMessage(score) {
  var messages = [
    "Perfect match! ❤️❤️❤️",
    "Very strong connection! ❤️❤️",
    "Strong love! ❤️",
    "Good compatibility! 💖",
    "Some sparks! 💘",
    "Not a great match... 💔",
    "No love here... 💔💔💔"
  ];

  if (score >= 90) {
    return messages[0] + " (" + score + "%)";
  } else if (score >= 80) {
    return messages[1] + " (" + score + "%)";
  } else if (score >= 70) {
    return messages[2] + " (" + score + "%)";
  } else if (score >= 60) {
    return messages[3] + " (" + score + "%)";
  } else if (score >= 50) {
    return messages[4] + " (" + score + "%)";
  } else if (score >= 40) {
    return messages[5] + " (" + score + "%)";
  } else {
    return messages[6] + " (" + score + "%)";
  }
}

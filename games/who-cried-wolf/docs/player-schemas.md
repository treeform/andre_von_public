# Player protocol JSON schemas

The authenticated WebSocket exchanges ready, observation, action, receipt, and end messages. Copy request identifiers exactly. All messages are JSON text. Observation and control messages come from the game; actions come from the policy.

## Observation

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "protocol": {
      "type": "string",
      "const": "wcw.player/1"
    },
    "type": {
      "type": "string",
      "const": "observation"
    },
    "episodeId": {
      "type": "string",
      "pattern": "^[A-Za-z0-9_-]{1,80}$"
    },
    "observationId": {
      "type": "string",
      "pattern": "^[A-Za-z0-9_-]{1,80}$"
    },
    "requestId": {
      "type": "string",
      "pattern": "^[A-Za-z0-9_-]{1,80}$"
    },
    "attempt": {
      "anyOf": [
        {
          "type": "number",
          "const": 0
        },
        {
          "type": "number",
          "const": 1
        }
      ]
    },
    "remainingMs": {
      "type": "integer",
      "minimum": 0,
      "maximum": 45000
    },
    "phase": {
      "type": "string",
      "enum": [
        "waiting",
        "day",
        "vote",
        "night",
        "finished"
      ]
    },
    "day": {
      "type": "integer",
      "minimum": 0,
      "maximum": 32
    },
    "self": {
      "type": "object",
      "properties": {
        "slot": {
          "type": "integer",
          "minimum": 0,
          "maximum": 8
        },
        "role": {
          "type": "string",
          "enum": [
            "wolf",
            "alchemist",
            "track_reader",
            "seer",
            "guard",
            "chef",
            "dairy_maid",
            "priest",
            "noble",
            "sheep",
            "jester"
          ]
        },
        "faction": {
          "type": "string",
          "enum": [
            "wolf",
            "town",
            "solo"
          ]
        },
        "alive": {
          "type": "boolean"
        }
      },
      "required": [
        "slot",
        "role",
        "faction",
        "alive"
      ],
      "additionalProperties": false
    },
    "roster": {
      "minItems": 9,
      "maxItems": 9,
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "slot": {
            "type": "integer",
            "minimum": 0,
            "maximum": 8
          },
          "name": {
            "type": "string"
          },
          "policyName": {
            "type": "string"
          },
          "alive": {
            "type": "boolean"
          },
          "presentation": {
            "oneOf": [
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "neutral"
                  }
                },
                "required": [
                  "kind"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "character"
                  },
                  "characterId": {
                    "type": "string",
                    "pattern": "^[a-z0-9][a-z0-9_-]{0,47}$"
                  },
                  "persona": {
                    "type": "string"
                  }
                },
                "required": [
                  "kind",
                  "characterId",
                  "persona"
                ],
                "additionalProperties": false
              }
            ]
          }
        },
        "required": [
          "slot",
          "name",
          "alive",
          "presentation"
        ],
        "additionalProperties": false
      }
    },
    "teammates": {
      "maxItems": 3,
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "slot": {
            "type": "integer",
            "minimum": 0,
            "maximum": 8
          },
          "role": {
            "type": "string",
            "enum": [
              "wolf",
              "alchemist",
              "track_reader",
              "noble"
            ]
          }
        },
        "required": [
          "slot",
          "role"
        ],
        "additionalProperties": false
      }
    },
    "privateResults": {
      "maxItems": 288,
      "type": "array",
      "items": {
        "oneOf": [
          {
            "type": "object",
            "properties": {
              "day": {
                "type": "integer",
                "minimum": 0,
                "maximum": 32
              },
              "ability": {
                "type": "string",
                "const": "inspect"
              },
              "target": {
                "type": "integer",
                "minimum": 0,
                "maximum": 8
              },
              "result": {
                "type": "string",
                "enum": [
                  "wolf",
                  "not_wolf",
                  "no_result"
                ]
              }
            },
            "required": [
              "day",
              "ability",
              "target",
              "result"
            ],
            "additionalProperties": false
          },
          {
            "type": "object",
            "properties": {
              "day": {
                "type": "integer",
                "minimum": 0,
                "maximum": 32
              },
              "ability": {
                "type": "string",
                "const": "check"
              },
              "target": {
                "type": "integer",
                "minimum": 0,
                "maximum": 8
              },
              "result": {
                "anyOf": [
                  {
                    "type": "string",
                    "enum": [
                      "wolf",
                      "alchemist",
                      "track_reader",
                      "seer",
                      "guard",
                      "chef",
                      "dairy_maid",
                      "priest",
                      "noble",
                      "sheep",
                      "jester"
                    ]
                  },
                  {
                    "type": "string",
                    "const": "vanilla"
                  },
                  {
                    "type": "string",
                    "const": "no_result"
                  }
                ]
              }
            },
            "required": [
              "day",
              "ability",
              "target",
              "result"
            ],
            "additionalProperties": false
          },
          {
            "type": "object",
            "properties": {
              "day": {
                "type": "integer",
                "minimum": 0,
                "maximum": 32
              },
              "ability": {
                "type": "string",
                "const": "inform"
              },
              "target": {
                "type": "integer",
                "minimum": 0,
                "maximum": 8
              },
              "result": {
                "type": "string",
                "const": "town"
              }
            },
            "required": [
              "day",
              "ability",
              "target",
              "result"
            ],
            "additionalProperties": false
          },
          {
            "type": "object",
            "properties": {
              "day": {
                "type": "integer",
                "minimum": 0,
                "maximum": 32
              },
              "ability": {
                "type": "string",
                "const": "track"
              },
              "target": {
                "type": "integer",
                "minimum": 0,
                "maximum": 8
              },
              "result": {
                "anyOf": [
                  {
                    "maxItems": 9,
                    "type": "array",
                    "items": {
                      "type": "integer",
                      "minimum": 0,
                      "maximum": 8
                    }
                  },
                  {
                    "type": "string",
                    "const": "no_result"
                  }
                ]
              }
            },
            "required": [
              "day",
              "ability",
              "target",
              "result"
            ],
            "additionalProperties": false
          }
        ]
      }
    },
    "votes": {
      "maxItems": 32,
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "day": {
            "type": "integer",
            "minimum": 0,
            "maximum": 32
          },
          "ballots": {
            "maxItems": 9,
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "slot": {
                  "type": "integer",
                  "minimum": 0,
                  "maximum": 8
                },
                "target": {
                  "anyOf": [
                    {
                      "type": "integer",
                      "minimum": 0,
                      "maximum": 8
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              },
              "required": [
                "slot",
                "target"
              ],
              "additionalProperties": false
            }
          },
          "eliminated": {
            "anyOf": [
              {
                "type": "integer",
                "minimum": 0,
                "maximum": 8
              },
              {
                "type": "null"
              }
            ]
          }
        },
        "required": [
          "day",
          "ballots",
          "eliminated"
        ],
        "additionalProperties": false
      }
    },
    "transcript": {
      "maxItems": 128,
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "schema": {
            "type": "string",
            "const": "wcw.events/1"
          },
          "id": {
            "type": "string",
            "pattern": "^[A-Za-z0-9_-]{1,80}$"
          },
          "cursor": {
            "type": "integer",
            "minimum": 1,
            "maximum": 20000
          },
          "day": {
            "type": "integer",
            "minimum": 0,
            "maximum": 32
          },
          "phase": {
            "type": "string",
            "enum": [
              "waiting",
              "day",
              "vote",
              "night",
              "finished"
            ]
          },
          "reveal": {
            "type": "string",
            "enum": [
              "public",
              "roles",
              "wolf_chat",
              "noble_chat",
              "dead_chat",
              "confessional",
              "night_choices",
              "discarded_bids",
              "failures",
              "beliefs"
            ]
          },
          "payload": {
            "oneOf": [
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "started"
                  },
                  "roster": {
                    "minItems": 9,
                    "maxItems": 9,
                    "type": "array",
                    "items": {
                      "type": "object",
                      "properties": {
                        "slot": {
                          "type": "integer",
                          "minimum": 0,
                          "maximum": 8
                        },
                        "name": {
                          "type": "string"
                        },
                        "policyName": {
                          "type": "string"
                        },
                        "alive": {
                          "type": "boolean"
                        },
                        "presentation": {
                          "oneOf": [
                            {
                              "type": "object",
                              "properties": {
                                "kind": {
                                  "type": "string",
                                  "const": "neutral"
                                }
                              },
                              "required": [
                                "kind"
                              ],
                              "additionalProperties": false
                            },
                            {
                              "type": "object",
                              "properties": {
                                "kind": {
                                  "type": "string",
                                  "const": "character"
                                },
                                "characterId": {
                                  "type": "string",
                                  "pattern": "^[a-z0-9][a-z0-9_-]{0,47}$"
                                },
                                "persona": {
                                  "type": "string"
                                }
                              },
                              "required": [
                                "kind",
                                "characterId",
                                "persona"
                              ],
                              "additionalProperties": false
                            }
                          ]
                        }
                      },
                      "required": [
                        "slot",
                        "name",
                        "alive",
                        "presentation"
                      ],
                      "additionalProperties": false
                    }
                  },
                  "rulesVersion": {
                    "type": "string",
                    "pattern": "^[\\x21-\\x7e]{1,80}$"
                  }
                },
                "required": [
                  "kind",
                  "roster",
                  "rulesVersion"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "phase"
                  },
                  "phase": {
                    "type": "string",
                    "enum": [
                      "waiting",
                      "day",
                      "vote",
                      "night",
                      "finished"
                    ]
                  },
                  "day": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 32
                  },
                  "durationMs": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 978000
                  }
                },
                "required": [
                  "kind",
                  "phase",
                  "day",
                  "durationMs"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "speech"
                  },
                  "speech": {
                    "type": "object",
                    "properties": {
                      "slot": {
                        "type": "integer",
                        "minimum": 0,
                        "maximum": 8
                      },
                      "text": {
                        "type": "string"
                      },
                      "replyTo": {
                        "anyOf": [
                          {
                            "type": "string",
                            "pattern": "^[A-Za-z0-9_-]{1,80}$"
                          },
                          {
                            "type": "null"
                          }
                        ]
                      },
                      "accusation": {
                        "anyOf": [
                          {
                            "type": "integer",
                            "minimum": 0,
                            "maximum": 8
                          },
                          {
                            "type": "null"
                          }
                        ]
                      }
                    },
                    "required": [
                      "slot",
                      "text",
                      "replyTo",
                      "accusation"
                    ],
                    "additionalProperties": false
                  }
                },
                "required": [
                  "kind",
                  "speech"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "wolf_chat"
                  },
                  "slot": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 8
                  },
                  "text": {
                    "type": "string"
                  }
                },
                "required": [
                  "kind",
                  "slot",
                  "text"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "noble_chat"
                  },
                  "slot": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 8
                  },
                  "text": {
                    "type": "string"
                  }
                },
                "required": [
                  "kind",
                  "slot",
                  "text"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "dead_chat"
                  },
                  "slot": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 8
                  },
                  "text": {
                    "type": "string"
                  }
                },
                "required": [
                  "kind",
                  "slot",
                  "text"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "confessional"
                  },
                  "slot": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 8
                  },
                  "requestKind": {
                    "type": "string",
                    "enum": [
                      "bid",
                      "wolf_chat",
                      "noble_chat",
                      "vote",
                      "night",
                      "dead_chat"
                    ]
                  },
                  "text": {
                    "type": "string"
                  }
                },
                "required": [
                  "kind",
                  "slot",
                  "requestKind",
                  "text"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "bid"
                  },
                  "slot": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 8
                  },
                  "window": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 17
                  },
                  "bid": {
                    "type": "object",
                    "properties": {
                      "kind": {
                        "type": "string",
                        "const": "bid"
                      },
                      "wantsToSpeak": {
                        "type": "boolean"
                      },
                      "urgency": {
                        "type": "integer",
                        "minimum": 0,
                        "maximum": 3
                      },
                      "text": {
                        "type": "string"
                      },
                      "replyTo": {
                        "anyOf": [
                          {
                            "type": "string",
                            "pattern": "^[A-Za-z0-9_-]{1,80}$"
                          },
                          {
                            "type": "null"
                          }
                        ]
                      },
                      "accusation": {
                        "anyOf": [
                          {
                            "type": "integer",
                            "minimum": 0,
                            "maximum": 8
                          },
                          {
                            "type": "null"
                          }
                        ]
                      },
                      "reason": {
                        "type": "string"
                      }
                    },
                    "required": [
                      "kind",
                      "wantsToSpeak",
                      "urgency",
                      "text",
                      "replyTo",
                      "accusation",
                      "reason"
                    ],
                    "additionalProperties": false
                  },
                  "rank": {
                    "anyOf": [
                      {
                        "type": "integer",
                        "minimum": 0,
                        "maximum": 8
                      },
                      {
                        "type": "null"
                      }
                    ]
                  },
                  "selected": {
                    "type": "boolean"
                  }
                },
                "required": [
                  "kind",
                  "slot",
                  "window",
                  "bid",
                  "rank",
                  "selected"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "ballots"
                  },
                  "ballots": {
                    "maxItems": 9,
                    "type": "array",
                    "items": {
                      "type": "object",
                      "properties": {
                        "slot": {
                          "type": "integer",
                          "minimum": 0,
                          "maximum": 8
                        },
                        "target": {
                          "anyOf": [
                            {
                              "type": "integer",
                              "minimum": 0,
                              "maximum": 8
                            },
                            {
                              "type": "null"
                            }
                          ]
                        }
                      },
                      "required": [
                        "slot",
                        "target"
                      ],
                      "additionalProperties": false
                    }
                  },
                  "eliminated": {
                    "anyOf": [
                      {
                        "type": "integer",
                        "minimum": 0,
                        "maximum": 8
                      },
                      {
                        "type": "null"
                      }
                    ]
                  },
                  "resolution": {
                    "type": "string",
                    "enum": [
                      "majority",
                      "no_majority",
                      "tie",
                      "all_abstain"
                    ]
                  }
                },
                "required": [
                  "kind",
                  "ballots",
                  "eliminated",
                  "resolution"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "night_choices"
                  },
                  "slot": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 8
                  },
                  "actions": {
                    "maxItems": 2,
                    "type": "array",
                    "items": {
                      "type": "object",
                      "properties": {
                        "ability": {
                          "type": "string",
                          "enum": [
                            "kill",
                            "block",
                            "inspect",
                            "protect",
                            "jail",
                            "check",
                            "inform",
                            "track"
                          ]
                        },
                        "target": {
                          "anyOf": [
                            {
                              "type": "integer",
                              "minimum": 0,
                              "maximum": 8
                            },
                            {
                              "type": "null"
                            }
                          ]
                        },
                        "killer": {
                          "type": "integer",
                          "minimum": 0,
                          "maximum": 8
                        }
                      },
                      "required": [
                        "ability",
                        "target"
                      ],
                      "additionalProperties": false
                    }
                  }
                },
                "required": [
                  "kind",
                  "slot",
                  "actions"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "night_outcome"
                  },
                  "ability": {
                    "type": "string",
                    "enum": [
                      "kill",
                      "block",
                      "inspect",
                      "protect",
                      "jail",
                      "check",
                      "inform",
                      "track"
                    ]
                  },
                  "actor": {
                    "anyOf": [
                      {
                        "type": "integer",
                        "minimum": 0,
                        "maximum": 8
                      },
                      {
                        "type": "null"
                      }
                    ]
                  },
                  "target": {
                    "anyOf": [
                      {
                        "type": "integer",
                        "minimum": 0,
                        "maximum": 8
                      },
                      {
                        "type": "null"
                      }
                    ]
                  },
                  "outcome": {
                    "type": "string",
                    "enum": [
                      "applied",
                      "blocked",
                      "protected",
                      "passed",
                      "actor_dead"
                    ]
                  }
                },
                "required": [
                  "kind",
                  "ability",
                  "actor",
                  "target",
                  "outcome"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "private_result"
                  },
                  "slot": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 8
                  },
                  "result": {
                    "oneOf": [
                      {
                        "type": "object",
                        "properties": {
                          "day": {
                            "type": "integer",
                            "minimum": 0,
                            "maximum": 32
                          },
                          "ability": {
                            "type": "string",
                            "const": "inspect"
                          },
                          "target": {
                            "type": "integer",
                            "minimum": 0,
                            "maximum": 8
                          },
                          "result": {
                            "type": "string",
                            "enum": [
                              "wolf",
                              "not_wolf",
                              "no_result"
                            ]
                          }
                        },
                        "required": [
                          "day",
                          "ability",
                          "target",
                          "result"
                        ],
                        "additionalProperties": false
                      },
                      {
                        "type": "object",
                        "properties": {
                          "day": {
                            "type": "integer",
                            "minimum": 0,
                            "maximum": 32
                          },
                          "ability": {
                            "type": "string",
                            "const": "check"
                          },
                          "target": {
                            "type": "integer",
                            "minimum": 0,
                            "maximum": 8
                          },
                          "result": {
                            "anyOf": [
                              {
                                "type": "string",
                                "enum": [
                                  "wolf",
                                  "alchemist",
                                  "track_reader",
                                  "seer",
                                  "guard",
                                  "chef",
                                  "dairy_maid",
                                  "priest",
                                  "noble",
                                  "sheep",
                                  "jester"
                                ]
                              },
                              {
                                "type": "string",
                                "const": "vanilla"
                              },
                              {
                                "type": "string",
                                "const": "no_result"
                              }
                            ]
                          }
                        },
                        "required": [
                          "day",
                          "ability",
                          "target",
                          "result"
                        ],
                        "additionalProperties": false
                      },
                      {
                        "type": "object",
                        "properties": {
                          "day": {
                            "type": "integer",
                            "minimum": 0,
                            "maximum": 32
                          },
                          "ability": {
                            "type": "string",
                            "const": "inform"
                          },
                          "target": {
                            "type": "integer",
                            "minimum": 0,
                            "maximum": 8
                          },
                          "result": {
                            "type": "string",
                            "const": "town"
                          }
                        },
                        "required": [
                          "day",
                          "ability",
                          "target",
                          "result"
                        ],
                        "additionalProperties": false
                      },
                      {
                        "type": "object",
                        "properties": {
                          "day": {
                            "type": "integer",
                            "minimum": 0,
                            "maximum": 32
                          },
                          "ability": {
                            "type": "string",
                            "const": "track"
                          },
                          "target": {
                            "type": "integer",
                            "minimum": 0,
                            "maximum": 8
                          },
                          "result": {
                            "anyOf": [
                              {
                                "maxItems": 9,
                                "type": "array",
                                "items": {
                                  "type": "integer",
                                  "minimum": 0,
                                  "maximum": 8
                                }
                              },
                              {
                                "type": "string",
                                "const": "no_result"
                              }
                            ]
                          }
                        },
                        "required": [
                          "day",
                          "ability",
                          "target",
                          "result"
                        ],
                        "additionalProperties": false
                      }
                    ]
                  }
                },
                "required": [
                  "kind",
                  "slot",
                  "result"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "elimination"
                  },
                  "slot": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 8
                  },
                  "cause": {
                    "type": "string",
                    "enum": [
                      "vote",
                      "wolf"
                    ]
                  },
                  "role": {
                    "type": "string",
                    "enum": [
                      "wolf",
                      "alchemist",
                      "track_reader",
                      "seer",
                      "guard",
                      "chef",
                      "dairy_maid",
                      "priest",
                      "noble",
                      "sheep",
                      "jester"
                    ]
                  },
                  "faction": {
                    "type": "string",
                    "enum": [
                      "wolf",
                      "town",
                      "solo"
                    ]
                  }
                },
                "required": [
                  "kind",
                  "slot",
                  "cause"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "suspicion"
                  },
                  "slot": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 8
                  },
                  "reports": {
                    "minItems": 1,
                    "maxItems": 8,
                    "type": "array",
                    "items": {
                      "type": "object",
                      "properties": {
                        "slot": {
                          "type": "integer",
                          "minimum": 0,
                          "maximum": 8
                        },
                        "wolf": {
                          "type": "number",
                          "minimum": 0,
                          "maximum": 1
                        }
                      },
                      "required": [
                        "slot",
                        "wolf"
                      ],
                      "additionalProperties": false
                    }
                  }
                },
                "required": [
                  "kind",
                  "slot",
                  "reports"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "suspicion_dropped"
                  },
                  "slot": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 8
                  },
                  "reason": {
                    "type": "string",
                    "enum": [
                      "missing",
                      "wrong_count",
                      "unknown_player",
                      "duplicate_player",
                      "out_of_range"
                    ]
                  },
                  "player": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 8
                  }
                },
                "required": [
                  "kind",
                  "slot",
                  "reason"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "kill_resolution"
                  },
                  "targetVotes": {
                    "maxItems": 9,
                    "type": "array",
                    "items": {
                      "type": "object",
                      "properties": {
                        "target": {
                          "type": "integer",
                          "minimum": 0,
                          "maximum": 8
                        },
                        "votes": {
                          "type": "integer",
                          "minimum": 1,
                          "maximum": 9
                        }
                      },
                      "required": [
                        "target",
                        "votes"
                      ],
                      "additionalProperties": false
                    }
                  },
                  "knifeVotes": {
                    "maxItems": 9,
                    "type": "array",
                    "items": {
                      "type": "object",
                      "properties": {
                        "killer": {
                          "type": "integer",
                          "minimum": 0,
                          "maximum": 8
                        },
                        "votes": {
                          "type": "integer",
                          "minimum": 1,
                          "maximum": 9
                        }
                      },
                      "required": [
                        "killer",
                        "votes"
                      ],
                      "additionalProperties": false
                    }
                  },
                  "targetTie": {
                    "type": "boolean"
                  },
                  "knifeTie": {
                    "type": "boolean"
                  },
                  "target": {
                    "anyOf": [
                      {
                        "type": "integer",
                        "minimum": 0,
                        "maximum": 8
                      },
                      {
                        "type": "null"
                      }
                    ]
                  },
                  "killer": {
                    "anyOf": [
                      {
                        "type": "integer",
                        "minimum": 0,
                        "maximum": 8
                      },
                      {
                        "type": "null"
                      }
                    ]
                  }
                },
                "required": [
                  "kind",
                  "targetVotes",
                  "knifeVotes",
                  "targetTie",
                  "knifeTie",
                  "target",
                  "killer"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "night_resolved"
                  },
                  "eliminated": {
                    "maxItems": 9,
                    "type": "array",
                    "items": {
                      "type": "integer",
                      "minimum": 0,
                      "maximum": 8
                    }
                  }
                },
                "required": [
                  "kind",
                  "eliminated"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "failure"
                  },
                  "slot": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 8
                  },
                  "requestKind": {
                    "type": "string",
                    "enum": [
                      "bid",
                      "wolf_chat",
                      "noble_chat",
                      "vote",
                      "night",
                      "dead_chat"
                    ]
                  },
                  "code": {
                    "type": "string",
                    "enum": [
                      "timeout",
                      "disconnected",
                      "malformed",
                      "illegal",
                      "refused",
                      "provider_error",
                      "throttled",
                      "version"
                    ]
                  },
                  "source": {
                    "type": "string",
                    "enum": [
                      "game",
                      "policy_report"
                    ]
                  },
                  "disposition": {
                    "type": "string",
                    "enum": [
                      "retry",
                      "fallback"
                    ]
                  },
                  "attempt": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 2
                  }
                },
                "required": [
                  "kind",
                  "slot",
                  "requestKind",
                  "code",
                  "source",
                  "disposition",
                  "attempt"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "finished"
                  },
                  "result": {
                    "anyOf": [
                      {
                        "type": "object",
                        "properties": {
                          "schema": {
                            "type": "string",
                            "const": "wcw.results/2"
                          },
                          "rulesVersion": {
                            "type": "string",
                            "pattern": "^[\\x21-\\x7e]{1,80}$"
                          },
                          "outcome": {
                            "type": "string",
                            "enum": [
                              "town_win",
                              "wolf_win",
                              "jester_win",
                              "draw"
                            ]
                          },
                          "reason": {
                            "type": "string",
                            "enum": [
                              "wolves_eliminated",
                              "wolf_parity",
                              "jester_voted_out",
                              "day_cap"
                            ]
                          },
                          "daysCompleted": {
                            "type": "integer",
                            "minimum": 0,
                            "maximum": 32
                          },
                          "scores": {
                            "minItems": 9,
                            "maxItems": 9,
                            "type": "array",
                            "items": {
                              "type": "number",
                              "minimum": 0,
                              "maximum": 1
                            }
                          },
                          "metrics": {
                            "minItems": 9,
                            "maxItems": 9,
                            "type": "array",
                            "items": {
                              "type": "object",
                              "properties": {
                                "win": {
                                  "anyOf": [
                                    {
                                      "type": "number",
                                      "const": 0
                                    },
                                    {
                                      "type": "number",
                                      "const": 1
                                    }
                                  ]
                                },
                                "read": {
                                  "type": "number",
                                  "minimum": 0,
                                  "maximum": 1
                                },
                                "hidden": {
                                  "type": "number",
                                  "minimum": 0,
                                  "maximum": 1
                                },
                                "vote_hit": {
                                  "type": "number",
                                  "minimum": 0,
                                  "maximum": 1
                                },
                                "survived": {
                                  "type": "number",
                                  "minimum": 0,
                                  "maximum": 1
                                },
                                "valid_actions": {
                                  "type": "number",
                                  "minimum": 0,
                                  "maximum": 1
                                }
                              },
                              "required": [
                                "win"
                              ],
                              "additionalProperties": false
                            }
                          }
                        },
                        "required": [
                          "schema",
                          "rulesVersion",
                          "outcome",
                          "reason",
                          "daysCompleted",
                          "scores",
                          "metrics"
                        ],
                        "additionalProperties": false
                      },
                      {
                        "type": "object",
                        "properties": {
                          "schema": {
                            "type": "string",
                            "const": "wcw.results/1"
                          },
                          "rulesVersion": {
                            "type": "string",
                            "pattern": "^[\\x21-\\x7e]{1,80}$"
                          },
                          "outcome": {
                            "type": "string",
                            "enum": [
                              "town_win",
                              "wolf_win",
                              "jester_win",
                              "draw"
                            ]
                          },
                          "reason": {
                            "type": "string",
                            "enum": [
                              "wolves_eliminated",
                              "wolf_parity",
                              "jester_voted_out",
                              "day_cap"
                            ]
                          },
                          "daysCompleted": {
                            "type": "integer",
                            "minimum": 0,
                            "maximum": 32
                          },
                          "scores": {
                            "minItems": 9,
                            "maxItems": 9,
                            "type": "array",
                            "items": {
                              "type": "integer",
                              "minimum": 0,
                              "maximum": 1
                            }
                          }
                        },
                        "required": [
                          "schema",
                          "rulesVersion",
                          "outcome",
                          "reason",
                          "daysCompleted",
                          "scores"
                        ],
                        "additionalProperties": false
                      }
                    ]
                  }
                },
                "required": [
                  "kind",
                  "result"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "roles"
                  },
                  "roles": {
                    "minItems": 9,
                    "maxItems": 9,
                    "type": "array",
                    "items": {
                      "type": "object",
                      "properties": {
                        "slot": {
                          "type": "integer",
                          "minimum": 0,
                          "maximum": 8
                        },
                        "role": {
                          "type": "string",
                          "enum": [
                            "wolf",
                            "alchemist",
                            "track_reader",
                            "seer",
                            "guard",
                            "chef",
                            "dairy_maid",
                            "priest",
                            "noble",
                            "sheep",
                            "jester"
                          ]
                        },
                        "faction": {
                          "type": "string",
                          "enum": [
                            "wolf",
                            "town",
                            "solo"
                          ]
                        }
                      },
                      "required": [
                        "slot",
                        "role",
                        "faction"
                      ],
                      "additionalProperties": false
                    }
                  }
                },
                "required": [
                  "kind",
                  "roles"
                ],
                "additionalProperties": false
              },
              {
                "type": "object",
                "properties": {
                  "kind": {
                    "type": "string",
                    "const": "seed"
                  },
                  "seed": {
                    "type": "string",
                    "pattern": "^[0-9a-f]{32}$"
                  },
                  "randomVersion": {
                    "type": "string",
                    "const": "sha256-counter/1"
                  }
                },
                "required": [
                  "kind",
                  "seed",
                  "randomVersion"
                ],
                "additionalProperties": false
              }
            ]
          }
        },
        "required": [
          "schema",
          "id",
          "cursor",
          "day",
          "phase",
          "reveal",
          "payload"
        ],
        "additionalProperties": false
      }
    },
    "transcriptTruncated": {
      "type": "boolean"
    },
    "request": {
      "oneOf": [
        {
          "type": "object",
          "properties": {
            "kind": {
              "type": "string",
              "const": "bid"
            },
            "window": {
              "type": "integer",
              "minimum": 0,
              "maximum": 17
            },
            "maxCharacters": {
              "type": "number",
              "const": 480
            },
            "host": {
              "type": "object",
              "properties": {
                "reason": {
                  "type": "string",
                  "enum": [
                    "human_reply",
                    "open_discussion"
                  ]
                },
                "replyTo": {
                  "anyOf": [
                    {
                      "type": "string",
                      "pattern": "^[A-Za-z0-9_-]{1,80}$"
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "prompt": {
                  "type": "string",
                  "maxLength": 240
                }
              },
              "required": [
                "reason",
                "replyTo"
              ],
              "additionalProperties": false
            }
          },
          "required": [
            "kind",
            "window",
            "maxCharacters"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "kind": {
              "type": "string",
              "const": "wolf_chat"
            },
            "turn": {
              "type": "integer",
              "minimum": 0,
              "maximum": 17
            },
            "maxCharacters": {
              "type": "number",
              "const": 480
            }
          },
          "required": [
            "kind",
            "turn",
            "maxCharacters"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "kind": {
              "type": "string",
              "const": "noble_chat"
            },
            "turn": {
              "type": "integer",
              "minimum": 0,
              "maximum": 17
            },
            "maxCharacters": {
              "type": "number",
              "const": 480
            }
          },
          "required": [
            "kind",
            "turn",
            "maxCharacters"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "kind": {
              "type": "string",
              "const": "vote"
            },
            "targets": {
              "maxItems": 9,
              "type": "array",
              "items": {
                "type": "integer",
                "minimum": 0,
                "maximum": 8
              }
            },
            "allowPass": {
              "type": "boolean",
              "const": true
            },
            "suspicion": {
              "type": "boolean",
              "const": true
            }
          },
          "required": [
            "kind",
            "targets",
            "allowPass"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "kind": {
              "type": "string",
              "const": "night"
            },
            "choices": {
              "maxItems": 2,
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "ability": {
                    "type": "string",
                    "enum": [
                      "kill",
                      "block",
                      "inspect",
                      "protect",
                      "jail",
                      "check",
                      "inform",
                      "track"
                    ]
                  },
                  "targets": {
                    "maxItems": 9,
                    "type": "array",
                    "items": {
                      "type": "integer",
                      "minimum": 0,
                      "maximum": 8
                    }
                  },
                  "allowPass": {
                    "type": "boolean",
                    "const": true
                  },
                  "actors": {
                    "maxItems": 3,
                    "type": "array",
                    "items": {
                      "type": "integer",
                      "minimum": 0,
                      "maximum": 8
                    }
                  }
                },
                "required": [
                  "ability",
                  "targets",
                  "allowPass"
                ],
                "additionalProperties": false
              }
            }
          },
          "required": [
            "kind",
            "choices"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "kind": {
              "type": "string",
              "const": "dead_chat"
            },
            "maxCharacters": {
              "type": "number",
              "const": 240
            }
          },
          "required": [
            "kind",
            "maxCharacters"
          ],
          "additionalProperties": false
        }
      ]
    }
  },
  "required": [
    "protocol",
    "type",
    "episodeId",
    "observationId",
    "requestId",
    "attempt",
    "remainingMs",
    "phase",
    "day",
    "self",
    "roster",
    "teammates",
    "privateResults",
    "votes",
    "transcript",
    "transcriptTruncated",
    "request"
  ],
  "additionalProperties": false
}
```

## Action

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "protocol": {
      "type": "string",
      "const": "wcw.player/1"
    },
    "type": {
      "type": "string",
      "const": "action"
    },
    "episodeId": {
      "type": "string",
      "pattern": "^[A-Za-z0-9_-]{1,80}$"
    },
    "requestId": {
      "type": "string",
      "pattern": "^[A-Za-z0-9_-]{1,80}$"
    },
    "observationId": {
      "type": "string",
      "pattern": "^[A-Za-z0-9_-]{1,80}$"
    },
    "body": {
      "oneOf": [
        {
          "type": "object",
          "properties": {
            "kind": {
              "type": "string",
              "const": "bid"
            },
            "wantsToSpeak": {
              "type": "boolean"
            },
            "urgency": {
              "type": "integer",
              "minimum": 0,
              "maximum": 3
            },
            "text": {
              "type": "string"
            },
            "replyTo": {
              "anyOf": [
                {
                  "type": "string",
                  "pattern": "^[A-Za-z0-9_-]{1,80}$"
                },
                {
                  "type": "null"
                }
              ]
            },
            "accusation": {
              "anyOf": [
                {
                  "type": "integer",
                  "minimum": 0,
                  "maximum": 8
                },
                {
                  "type": "null"
                }
              ]
            },
            "reason": {
              "type": "string"
            }
          },
          "required": [
            "kind",
            "wantsToSpeak",
            "urgency",
            "text",
            "replyTo",
            "accusation",
            "reason"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "kind": {
              "type": "string",
              "const": "wolf_chat"
            },
            "text": {
              "type": "string"
            },
            "summary": {
              "type": "string"
            }
          },
          "required": [
            "kind",
            "text",
            "summary"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "kind": {
              "type": "string",
              "const": "noble_chat"
            },
            "text": {
              "type": "string"
            },
            "summary": {
              "type": "string"
            }
          },
          "required": [
            "kind",
            "text",
            "summary"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "kind": {
              "type": "string",
              "const": "dead_chat"
            },
            "text": {
              "type": "string"
            },
            "summary": {
              "type": "string"
            }
          },
          "required": [
            "kind",
            "text",
            "summary"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "kind": {
              "type": "string",
              "const": "vote"
            },
            "target": {
              "anyOf": [
                {
                  "type": "integer",
                  "minimum": 0,
                  "maximum": 8
                },
                {
                  "type": "null"
                }
              ]
            },
            "summary": {
              "type": "string"
            },
            "suspicion": {
              "maxItems": 9,
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "slot": {
                    "type": "integer",
                    "minimum": -9007199254740991,
                    "maximum": 9007199254740991
                  },
                  "wolf": {
                    "type": "number"
                  }
                },
                "required": [
                  "slot",
                  "wolf"
                ],
                "additionalProperties": false
              }
            }
          },
          "required": [
            "kind",
            "target",
            "summary"
          ],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "kind": {
              "type": "string",
              "const": "night"
            },
            "actions": {
              "maxItems": 2,
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "ability": {
                    "type": "string",
                    "enum": [
                      "kill",
                      "block",
                      "inspect",
                      "protect",
                      "jail",
                      "check",
                      "inform",
                      "track"
                    ]
                  },
                  "target": {
                    "anyOf": [
                      {
                        "type": "integer",
                        "minimum": 0,
                        "maximum": 8
                      },
                      {
                        "type": "null"
                      }
                    ]
                  },
                  "killer": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 8
                  }
                },
                "required": [
                  "ability",
                  "target"
                ],
                "additionalProperties": false
              }
            },
            "summary": {
              "type": "string"
            }
          },
          "required": [
            "kind",
            "actions",
            "summary"
          ],
          "additionalProperties": false
        }
      ]
    },
    "report": {
      "anyOf": [
        {
          "type": "object",
          "properties": {
            "code": {
              "type": "string",
              "enum": [
                "refused",
                "provider_error",
                "throttled"
              ]
            },
            "attempts": {
              "anyOf": [
                {
                  "type": "number",
                  "const": 0
                },
                {
                  "type": "number",
                  "const": 1
                },
                {
                  "type": "number",
                  "const": 2
                }
              ]
            }
          },
          "required": [
            "code",
            "attempts"
          ],
          "additionalProperties": false
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "required": [
    "protocol",
    "type",
    "episodeId",
    "requestId",
    "observationId",
    "body",
    "report"
  ],
  "additionalProperties": false
}
```

## Control

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "oneOf": [
    {
      "type": "object",
      "properties": {
        "protocol": {
          "type": "string",
          "const": "wcw.player/1"
        },
        "type": {
          "type": "string",
          "const": "ready"
        },
        "episodeId": {
          "type": "string",
          "pattern": "^[A-Za-z0-9_-]{1,80}$"
        },
        "slot": {
          "type": "integer",
          "minimum": 0,
          "maximum": 8
        },
        "canRegisterName": {
          "type": "boolean"
        }
      },
      "required": [
        "protocol",
        "type",
        "episodeId",
        "slot"
      ],
      "additionalProperties": false
    },
    {
      "type": "object",
      "properties": {
        "protocol": {
          "type": "string",
          "const": "wcw.player/1"
        },
        "type": {
          "type": "string",
          "const": "receipt"
        },
        "requestId": {
          "type": "string",
          "pattern": "^[A-Za-z0-9_-]{1,80}$"
        },
        "status": {
          "type": "string",
          "enum": [
            "accepted",
            "duplicate",
            "rejected",
            "expired"
          ]
        },
        "code": {
          "anyOf": [
            {
              "type": "string",
              "enum": [
                "timeout",
                "disconnected",
                "malformed",
                "illegal",
                "refused",
                "provider_error",
                "throttled",
                "version"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "retry": {
          "type": "boolean"
        }
      },
      "required": [
        "protocol",
        "type",
        "requestId",
        "status",
        "code",
        "retry"
      ],
      "additionalProperties": false
    },
    {
      "type": "object",
      "properties": {
        "protocol": {
          "type": "string",
          "const": "wcw.player/1"
        },
        "type": {
          "type": "string",
          "const": "end"
        },
        "episodeId": {
          "type": "string",
          "pattern": "^[A-Za-z0-9_-]{1,80}$"
        },
        "result": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "schema": {
                  "type": "string",
                  "const": "wcw.results/2"
                },
                "rulesVersion": {
                  "type": "string",
                  "pattern": "^[\\x21-\\x7e]{1,80}$"
                },
                "outcome": {
                  "type": "string",
                  "enum": [
                    "town_win",
                    "wolf_win",
                    "jester_win",
                    "draw"
                  ]
                },
                "reason": {
                  "type": "string",
                  "enum": [
                    "wolves_eliminated",
                    "wolf_parity",
                    "jester_voted_out",
                    "day_cap"
                  ]
                },
                "daysCompleted": {
                  "type": "integer",
                  "minimum": 0,
                  "maximum": 32
                },
                "scores": {
                  "minItems": 9,
                  "maxItems": 9,
                  "type": "array",
                  "items": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1
                  }
                },
                "metrics": {
                  "minItems": 9,
                  "maxItems": 9,
                  "type": "array",
                  "items": {
                    "type": "object",
                    "properties": {
                      "win": {
                        "anyOf": [
                          {
                            "type": "number",
                            "const": 0
                          },
                          {
                            "type": "number",
                            "const": 1
                          }
                        ]
                      },
                      "read": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1
                      },
                      "hidden": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1
                      },
                      "vote_hit": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1
                      },
                      "survived": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1
                      },
                      "valid_actions": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1
                      }
                    },
                    "required": [
                      "win"
                    ],
                    "additionalProperties": false
                  }
                }
              },
              "required": [
                "schema",
                "rulesVersion",
                "outcome",
                "reason",
                "daysCompleted",
                "scores",
                "metrics"
              ],
              "additionalProperties": false
            },
            {
              "type": "object",
              "properties": {
                "schema": {
                  "type": "string",
                  "const": "wcw.results/1"
                },
                "rulesVersion": {
                  "type": "string",
                  "pattern": "^[\\x21-\\x7e]{1,80}$"
                },
                "outcome": {
                  "type": "string",
                  "enum": [
                    "town_win",
                    "wolf_win",
                    "jester_win",
                    "draw"
                  ]
                },
                "reason": {
                  "type": "string",
                  "enum": [
                    "wolves_eliminated",
                    "wolf_parity",
                    "jester_voted_out",
                    "day_cap"
                  ]
                },
                "daysCompleted": {
                  "type": "integer",
                  "minimum": 0,
                  "maximum": 32
                },
                "scores": {
                  "minItems": 9,
                  "maxItems": 9,
                  "type": "array",
                  "items": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 1
                  }
                }
              },
              "required": [
                "schema",
                "rulesVersion",
                "outcome",
                "reason",
                "daysCompleted",
                "scores"
              ],
              "additionalProperties": false
            }
          ]
        }
      },
      "required": [
        "protocol",
        "type",
        "episodeId",
        "result"
      ],
      "additionalProperties": false
    }
  ]
}
```

## Registration

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "protocol": {
      "type": "string",
      "const": "wcw.player/1"
    },
    "type": {
      "type": "string",
      "const": "register"
    },
    "displayName": {
      "type": "string",
      "minLength": 1,
      "maxLength": 32,
      "pattern": "^[A-Za-z0-9][A-Za-z0-9 ._-]*$"
    }
  },
  "required": [
    "protocol",
    "type",
    "displayName"
  ],
  "additionalProperties": false
}
```
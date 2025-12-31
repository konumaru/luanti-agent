"""Agent API Client for Luanti

This module provides a Python client for interacting with the agent_api Lua mod.
"""

from dataclasses import dataclass
from typing import List, Optional, Dict, Any
import json

try:
    import requests
    REQUESTS_AVAILABLE = True
except ImportError:
    REQUESTS_AVAILABLE = False


@dataclass
class Position:
    """3D position"""
    x: float
    y: float
    z: float
    
    @classmethod
    def from_dict(cls, data: Dict[str, float]) -> 'Position':
        return cls(x=data['x'], y=data['y'], z=data['z'])
    
    def to_dict(self) -> Dict[str, float]:
        return {'x': self.x, 'y': self.y, 'z': self.z}


@dataclass
class Orientation:
    """Agent orientation (yaw, pitch, look direction)"""
    yaw: float
    pitch: float
    look_dir: Position
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Orientation':
        return cls(
            yaw=data['yaw'],
            pitch=data['pitch'],
            look_dir=Position.from_dict(data['look_dir'])
        )


@dataclass
class Block:
    """Block information"""
    pos: Position
    name: str
    param1: int
    param2: int
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Block':
        return cls(
            pos=Position.from_dict(data['pos']),
            name=data['name'],
            param1=data['param1'],
            param2=data['param2']
        )


@dataclass
class Entity:
    """Entity information"""
    pos: Position
    distance: float
    name: str
    entity_type: str
    player_name: Optional[str] = None
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Entity':
        return cls(
            pos=Position.from_dict(data['pos']),
            distance=data['distance'],
            name=data['name'],
            entity_type=data.get('type', 'unknown'),
            player_name=data.get('player_name')
        )


@dataclass
class LookTarget:
    """What the agent is looking at"""
    target_type: str  # 'node' or 'object'
    distance: float
    pos: Optional[Position] = None
    name: Optional[str] = None
    
    @classmethod
    def from_dict(cls, data: Optional[Dict[str, Any]]) -> Optional['LookTarget']:
        if not data:
            return None
        return cls(
            target_type=data['type'],
            distance=data['distance'],
            pos=Position.from_dict(data['pos']) if 'pos' in data else None,
            name=data.get('name')
        )


@dataclass
class Observation:
    """Complete agent observation"""
    position: Position
    orientation: Orientation
    surrounding_blocks: List[Block]
    nearby_entities: List[Entity]
    look_target: Optional[LookTarget]
    health: int
    state: str
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Observation':
        return cls(
            position=Position.from_dict(data['position']),
            orientation=Orientation.from_dict(data['orientation']),
            surrounding_blocks=[Block.from_dict(b) for b in data['surrounding_blocks']],
            nearby_entities=[Entity.from_dict(e) for e in data['nearby_entities']],
            look_target=LookTarget.from_dict(data.get('look_target')),
            health=data['health'],
            state=data['state']
        )


class Action:
    """Base class for agent actions"""
    
    def to_dict(self) -> Dict[str, Any]:
        raise NotImplementedError


class MoveAction(Action):
    """Move in a direction"""
    
    def __init__(self, direction: str, speed: float = 1.0):
        """
        Args:
            direction: One of 'forward', 'backward', 'left', 'right', 'up', 'down'
            speed: Movement speed multiplier
        """
        self.direction = direction
        self.speed = speed
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'type': 'move',
            'direction': self.direction,
            'speed': self.speed
        }


class RotateAction(Action):
    """Rotate by delta angles"""
    
    def __init__(self, yaw_delta: Optional[float] = None, pitch_delta: Optional[float] = None):
        """
        Args:
            yaw_delta: Change in yaw (horizontal rotation)
            pitch_delta: Change in pitch (vertical rotation)
        """
        self.yaw_delta = yaw_delta
        self.pitch_delta = pitch_delta
    
    def to_dict(self) -> Dict[str, Any]:
        result = {'type': 'rotate'}
        if self.yaw_delta is not None:
            result['yaw_delta'] = self.yaw_delta
        if self.pitch_delta is not None:
            result['pitch_delta'] = self.pitch_delta
        return result


class LookAtAction(Action):
    """Look at absolute direction"""
    
    def __init__(self, yaw: Optional[float] = None, pitch: Optional[float] = None):
        """
        Args:
            yaw: Absolute yaw angle
            pitch: Absolute pitch angle
        """
        self.yaw = yaw
        self.pitch = pitch
    
    def to_dict(self) -> Dict[str, Any]:
        result = {'type': 'look_at'}
        if self.yaw is not None:
            result['yaw'] = self.yaw
        if self.pitch is not None:
            result['pitch'] = self.pitch
        return result


class DigAction(Action):
    """Dig/mine block at look target"""
    
    def to_dict(self) -> Dict[str, Any]:
        return {'type': 'dig'}


class PlaceAction(Action):
    """Place block at look target"""
    
    def __init__(self, node_name: str = "default:dirt"):
        """
        Args:
            node_name: Name of the node to place
        """
        self.node_name = node_name
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'type': 'place',
            'node_name': self.node_name
        }


class UseAction(Action):
    """Use/interact with target"""
    
    def to_dict(self) -> Dict[str, Any]:
        return {'type': 'use'}


class AgentClient:
    """Client for interacting with agent via the bot server"""
    
    def __init__(self, server_url: str = "http://localhost:8000"):
        self.server_url = server_url
        self.last_observation: Optional[Observation] = None
    
    def send_action(self, action: Action) -> bool:
        """Send an action to the agent
        
        Args:
            action: Action to execute
            
        Returns:
            True if successfully queued
        """
        if not REQUESTS_AVAILABLE:
            print("requests module not available. Install with: pip install requests")
            return False
            
        try:
            response = requests.post(
                f"{self.server_url}/enqueue",
                json=action.to_dict(),
                timeout=1.0
            )
            return response.status_code == 200
        except Exception as e:
            print(f"Failed to send action: {e}")
            return False
    
    def send_actions(self, actions: List[Action]) -> bool:
        """Send multiple actions to the agent
        
        Args:
            actions: List of actions to execute
            
        Returns:
            True if successfully queued
        """
        if not REQUESTS_AVAILABLE:
            print("requests module not available. Install with: pip install requests")
            return False
            
        try:
            response = requests.post(
                f"{self.server_url}/enqueue",
                json=[a.to_dict() for a in actions],
                timeout=1.0
            )
            return response.status_code == 200
        except Exception as e:
            print(f"Failed to send actions: {e}")
            return False
    
    def get_observation(self) -> Optional[Observation]:
        """Get the latest observation from the agent
        
        Note: Observation pushing from Lua to Python is not yet implemented.
        This is a placeholder for future enhancement where observations would
        be pushed from the Lua mod to Python via HTTP POST or WebSocket.
        
        Current implementation: The Lua mod collects observations internally
        but does not send them to Python. Actions are sent from Python to Lua
        via the command queue.
        
        Returns:
            Latest observation or None
        """
        return self.last_observation
    
    def update_observation(self, obs_data: Dict[str, Any]):
        """Update observation from received data
        
        This is a placeholder for when observation pushing is implemented.
        
        Args:
            obs_data: Observation data dictionary
        """
        self.last_observation = Observation.from_dict(obs_data)

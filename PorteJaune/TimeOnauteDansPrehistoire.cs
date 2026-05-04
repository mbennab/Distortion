using Godot;
using System;

public partial class TimeOnauteDansPrehistoire : Node2D
{
	private TimeOnautePrehistoire timeAunote;
	private Vector2 positionEntreePrincipale;
	public bool started = false;
	public bool stopped = true;
	
	// Called when the node enters the scene tree for the first time.
	public override void _Ready()
	{
		// charge les markers
		positionEntreePrincipale = GetNode<Marker2D>("fondPrehistoire/Markers2D/entreePrincipale").Position; 
		
		// charge et initialise le module TimeAunote
		Hide();
		//timeAunote = GetNode<TimeOnautePrehistoire>("TimeOnautePrehistoire");
		//timeAunote.apparition(positionEntreePrincipale);
	}

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
	}
	
	public void start(){
		Show();
		// charge et initialise le module TimeAunote
		timeAunote = GetNode<TimeOnautePrehistoire>("TimeOnautePrehistoire");
		timeAunote.apparition(positionEntreePrincipale);
		started = true;
		stopped = false;
	}	
	
	public void stop(){
		Hide();
		started = false;
		stopped = true;
	}	
}
